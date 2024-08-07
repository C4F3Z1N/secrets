{
  config,
  lib,
}:
with builtins // lib; let
  users = pipe ../sops/users [
    (filesystem.listFilesRecursive)
    # `-> [ ../sops/users/user0.json ../sops/users/user1.json ... ]
    (map (value: {
      inherit value;
      name = removeSuffix ".json" (baseNameOf value);
    }))
    # `-> [ { name = "user0"; value = ../sops/users/user0.json; } ... ]
    listToAttrs
    # `-> { user0 = ../sops/users/user0.json; ... }
  ];
in
  pipe users [
    (mapAttrsToList (user: sopsFile: {
      inherit user sopsFile;
      keys = attrNames (importJSON sopsFile);
      # `-> [ "secret0" "secret1" "sops" ... ]
    }))
    # `-> [ { user = "user0"; sopsFile = ../sops/users/user0.json; keys = [ ... ]; } ... ]
    (map ({
      keys,
      user,
      sopsFile,
    }:
      genAttrs keys (key: {inherit key user sopsFile;})))
    # `-> [ { secret0 = { key = "secret0"; user = "user0"; sopsFile = ...; }; } ... ]
    (map attrValues)
    # `-> [ [ { key = "secret0"; ... } ... ] ... ]
    flatten
    # `-> [ { key = "secret0"; ... } ... ]
    (filter ({key, ...}: key != "sops"))
    # `-> "sops" shouldn't be included (metadata);
    (map ({
      key,
      user,
      sopsFile,
    }:
      mkIf (hasAttr user config.users.users) {
        "${user}/${key}" = {
          inherit key sopsFile;
          format = "json";
        };
      }))
    mkMerge
  ]
