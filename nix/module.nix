{ config, lib, options, inputs ? { }, ... }:
with (builtins // lib);
let
  cfg = config.secrets;
  sopsCfg = config.sops.secrets;
  defaultSopsFile = ../sops/hosts + "/${config.networking.hostName}.json";
  sops-nix = attrByPath [ "sops-nix" ] (pipe ./flake.lock [
    (importJSON)
    (getAttrFromPath [ "nodes" "sops-nix" "locked" ])
    (flakeRefToString)
    (getFlake)
  ]) inputs;
in {
  imports = [ sops-nix.nixosModules.sops ];

  options.secrets = with types; {
    enable = mkOption {
      type = bool;
      default = pathExists defaultSopsFile;
    };

    gnupgHome = mkOption {
      type = path;
      default = "/etc/gnupg";
    };

    public = mkOption {
      type = attrs;
      default = importJSON ../public.json;
    };

    paths = mkOption {
      type = attrs;
      default = pipe defaultSopsFile [
        (importJSON)
        (filterAttrs (key: _: key != "sops"))
        (mapAttrs (key: _: sopsCfg."${key}".path))
      ];
    };

    users = mkOption {
      type = attrsOf (submodule ({ name, config, ... }: {
        options = {
          name = mkOption {
            type = str;
            default = name;
          };

          sopsFile = mkOption {
            type = path;
            default = ../sops/users + "/${name}.json";
          };

          paths = mkOption {
            type = attrs;
            default = pipe sopsCfg [
              (filterAttrs (key: _: hasPrefix "${name}/" key))
              (mapAttrs' (key:
                { path, ... }: {
                  name = removePrefix "${name}/" key;
                  value = path;
                }))
            ];
          };
        };
      }));

      default = pipe ../sops/users [
        (filesystem.listFilesRecursive)
        (map (sopsFile:
          nameValuePair (removeSuffix ".json" (baseNameOf sopsFile)) { }))
        listToAttrs
      ];
    };
  };

  config = mkIf cfg.enable {
    sops = rec {
      inherit defaultSopsFile;
      age.sshKeyPaths = lib.mkForce [ ];
      defaultSopsFormat = "json";

      gnupg = {
        inherit (age) sshKeyPaths;
        home = cfg.gnupgHome;
      };

      secrets = pipe cfg.users [
        (mapAttrs (username:
          { sopsFile, ... }:
          pipe sopsFile [
            (importJSON)
            (attrNames)
            (filter (key: key != "sops"))
            (map (key: { inherit key sopsFile username; }))
          ]))
        attrValues
        flatten
        (map ({ key, sopsFile, username, }:
          nameValuePair "${username}/${key}" {
            inherit key sopsFile;
            format = "json";
            neededForUsers = (key == "password");
          }))
        listToAttrs
      ];
    };

    users.users = mapAttrs (_:
      { paths, ... }:
      mkIf (paths ? password) {
        hashedPasswordFile = mkDefault paths.password;
      }) cfg.users;
  };
}
