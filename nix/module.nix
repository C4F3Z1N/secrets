{
  config,
  inputs ? {},
  lib,
  options,
  ...
}:
with builtins // lib; let
  inherit (config.networking) hostName;
  cfg = config.secrets;
  self = getFlake (toString ./.);
  sops-nix = inputs.sops-nix or self.inputs.sops-nix;
in {
  imports = [sops-nix.nixosModules.sops];

  options.secrets = with types; {
    enable = mkOption {
      type = bool;
      default = !isNull cfg.gnupg.home;
      defaultText = literalExpression "!isNull config.${options.secrets.gnupg.home}";
      description = "Whether to enable {option}`secrets`.";
    };

    decrypted = options.sops.secrets // {default = config.sops.secrets;};

    from = mkOption {
      type = listOf (
        # must be in JSON format;
        addCheck path (strings.hasSuffix ".json")
        # must be a SOPS file;
        // addCheck path (p: (trivial.importJSON p) ? sops)
        # (conditional) must be decryptable by ${cfg.gnupg.fingerprint};
        // attrsets.optionalAttrs (!isNull cfg.gnupg.fingerprint) (addCheck path (p:
            any ({fp, ...}: fp == cfg.gnupg.fingerprint) (trivial.importJSON p).sops.pgp))
      );

      default = lists.flatten (
        map filesystem.listFilesRecursive [
          ../sops/services
          ../sops/users
        ]
        ++ [(../sops/hosts + "/${hostName}.json")]
      );

      description = ''
        SOPS files in JSON format that contain the secrets to be imported.
        If the suffix `${hostName}.json` is detected, the file will be
        used as the default/base source of secrets.
      '';
    };

    gnupg = {
      inherit (options.sops.gnupg) home;

      fingerprint = mkOption {
        type = nullOr singleLineStr;
        default = null;

        description = ''
          If set, it will be used to verify that all SOPS files
          provided through {option}`secrets.from` can be decrypted
          by the secret key that has this fingerprint.
        '';
      };
    };

    public = mkOption {
      type = attrs;
      default = trivial.importJSON ../public.json;
      description = "Will be available as `_module.args.public`.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # use ../sops/hosts/${hostName}.json as the default source of secrets;
    (mkIf (any (strings.hasSuffix "${hostName}.json") cfg.from) {
      sops.defaultSopsFile = lists.findFirst (strings.hasSuffix "${hostName}.json") null cfg.from;
    })

    # basic config;
    {
      _module.args = {inherit (cfg) public;};

      sops = rec {
        # disable age;
        age.sshKeyPaths = mkForce [];
        defaultSopsFormat = "json";
        secrets = cfg.decrypted;

        gnupg = {
          inherit (age) sshKeyPaths;
          inherit (cfg.gnupg) home;
        };
      };
    }

    # process and setup other secrets;
    {
      secrets.decrypted = trivial.pipe cfg.from [
        # `-> [ ../sops/hosts/localhost.json ../sops/services/svc2.json ../sops/users/usr4.json ... ]
        (filter (sopsFile: sopsFile != config.sops.defaultSopsFile))
        # `-> [ ../sops/services/svc2.json ../sops/users/usr4.json ... ]
        (map (sopsFile: {
          inherit sopsFile;
          dirname = strings.removeSuffix ".json" (baseNameOf sopsFile);
          keys = attrNames (trivial.importJSON sopsFile);
        }))
        # `-> [ { dirname = "svc2"; sopsFile = ../sops/services/svc2.json; keys = [ ... ]; } ... ]
        (map ({
          dirname,
          keys,
          sopsFile,
        }:
          attrsets.genAttrs keys (key: {inherit dirname key sopsFile;})))
        # `-> [ { secret0 = { key = "secret0"; dirname = "svc2"; sopsFile = ...; } ... } ... ]
        (map attrValues)
        # `-> [ [ { key = "secret0"; dirname = "svc2"; sopsFile = ...; } ... ] ... ]
        (lists.flatten)
        # `-> [ { key = "secret0"; dirname = "svc2"; sopsFile = ...; } ... ]
        (map ({
          dirname,
          key,
          sopsFile,
        }:
          mkIf (key != "sops") {
            "${dirname}/${key}" = {
              inherit key sopsFile;
              format = "json";
              neededForUsers = (key == "password") && hasAttr dirname config.users.users;
            };
          }))
        # `-> [ { "svc2/secret0" = { key = "secret0"; sopsFile = ...; ... }; } ... ]
        mkMerge
        # `-> { "svc2/secret0" = { key = "secret0"; sopsFile = ...; ... }; "usr4/password" = { ... }; ... }
      ];
    }
  ]);
}
