{lib}:
with builtins // lib; let
  users = lib.pipe ../sops/users [
    (lib.filesystem.listFilesRecursive)
    # `-> [ ../sops/users/user0.json ../sops/users/user1.json ... ]
    (map (value: {
      inherit value;
      name = lib.removeSuffix ".json" (baseNameOf value);
    }))
    # `-> [ { name = "user0"; value = ../sops/users/user0.json; } ... ]
    (builtins.listToAttrs)
    # `-> { user0 = ../sops/users/user0.json; ... }
  ];
in
  lib.pipe users [
    (lib.mapAttrsToList (user: sopsFile: {
      inherit user sopsFile;
      keys = builtins.attrNames (lib.importJSON sopsFile);
      # `-> [ "secret0" "secret1" "sops" ... ]
    }))
    # `-> [ { user = "user0"; sopsFile = ../sops/users/user0.json; keys = [ ... ]; } ... ]
    (map ({
      keys,
      user,
      sopsFile,
    }:
      lib.genAttrs keys (key: {inherit key user sopsFile;})))
    # `-> [ { secret0 = { key = "secret0"; user = "user0"; sopsFile = ...; }; } ... ]
    (map (builtins.attrValues))
    # `-> [ [ { key = "secret0"; ... } ... ] ... ]
    (lib.flatten)
    # `-> [ { key = "secret0"; ... } ... ]
    (builtins.filter ({key, ...}: key != "sops"))
    # `-> "sops" shouldn't be included (metadata);
    (map ({
      key,
      user,
      sopsFile,
    }: {
      name = "${user}/${key}";
      value = {
        inherit key sopsFile;
        format = "json";
      };
    }))
    # `-> [ { name = "user0/secret0"; value = { key = "secret0"; ... }; } ... ]
    (builtins.listToAttrs)
    # `-> { "user0/secret0" = { ... }; "user0/secret1" = { ... }; "user1/secret0" = { ... }; ... }
  ]
