{
  config,
  lib,
}:
with builtins // lib; let
  services = pipe ../sops/services [
    (filesystem.listFilesRecursive)
    # `-> [ ../sops/services/svc0.json ../sops/services/svc1.json ... ]
    (map (value: {
      inherit value;
      name = removeSuffix ".json" (baseNameOf value);
    }))
    # `-> [ { name = "svc0"; value = ../sops/services/svc0.json; } ... ]
    listToAttrs
    # `-> { svc0 = ../sops/services/svc0.json; ... }
  ];
in
  pipe services [
    (mapAttrsToList (service: sopsFile: {
      inherit service sopsFile;
      keys = attrNames (importJSON sopsFile);
      # `-> [ "secret0" "secret1" "sops" ... ]
    }))
    # `-> [ { service = "svc0"; sopsFile = ../sops/services/svc0.json; keys = [ ... ]; } ... ]
    (map ({
      keys,
      service,
      sopsFile,
    }:
      genAttrs keys (key: {inherit key service sopsFile;})))
    # `-> [ { secret0 = { key = "secret0"; service = "svc0"; sopsFile = ...; }; } ... ]
    (map attrValues)
    # `-> [ [ { key = "secret0"; ... } ... ] ... ]
    flatten
    # `-> [ { key = "secret0"; ... } ... ]
    (filter ({key, ...}: key != "sops"))
    # `-> "sops" shouldn't be included (metadata);
    (map ({
      key,
      service,
      sopsFile,
    }: {
      "${service}/${key}" = {
        inherit key sopsFile;
        format = "json";
      };
    }))
    mkMerge
  ]
