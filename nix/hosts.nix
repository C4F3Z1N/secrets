{
  lib,
  sops-nix,
}:
with builtins // lib; let
  hosts = lib.pipe ../sops/hosts [
    (lib.filesystem.listFilesRecursive)
    # `-> [ ../sops/hosts/host0.json ../sops/hosts/host1.json ... ]
    (builtins.filter (file: !lib.hasSuffix "master-keys.json" file))
    # `-> "master-keys.json" shouldn't be included;
    (map (value: {
      inherit value;
      name = lib.removeSuffix ".json" (baseNameOf value);
    }))
    # `-> [ { name = "host0"; value = ../sops/hosts/host0.json; } ... ]
    (builtins.listToAttrs)
    # `-> { host0 = ../sops/hosts/host0.json; ... }
  ];
in
  # .-> { host0 = lib.nixosSystem { ... }; host1 = lib.nixosSystem { ... }; ... }
  mapAttrs (_: defaultSopsFile:
    lib.nixosSystem {
      modules = [
        sops-nix.nixosModules.sops
        {
          sops = {
            inherit defaultSopsFile;
            defaultSopsFormat = "json";
            secrets = import ./users.nix {inherit lib;};
          };
        }
      ];
    })
  hosts
