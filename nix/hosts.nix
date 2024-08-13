{
  lib,
  sops-nix,
}:
with builtins // lib; let
  hosts = pipe ../sops/hosts [
    (filesystem.listFilesRecursive)
    # `-> [ ../sops/hosts/host0.json ../sops/hosts/host1.json ... ]
    (filter (file: !hasSuffix "master-keys.json" file))
    # `-> "master-keys.json" shouldn't be included;
    (map (value: {
      inherit value;
      name = removeSuffix ".json" (baseNameOf value);
    }))
    # `-> [ { name = "host0"; value = ../sops/hosts/host0.json; } ... ]
    listToAttrs
    # `-> { host0 = ../sops/hosts/host0.json; ... }
  ];
in
  # .-> { host0 = nixosSystem { ... }; host1 = nixosSystem { ... }; ... }
  mapAttrs (_: defaultSopsFile:
    nixosSystem {
      specialArgs.public = importJSON ../public.json;
      modules = [
        sops-nix.nixosModules.sops
        ({config, ...}: {
          sops = {
            inherit defaultSopsFile;
            defaultSopsFormat = "json";
            secrets = import ./users.nix {inherit config lib;};
          };
        })
      ];
    })
  hosts
