{ lib ? (import <nixpkgs> { }).lib }:
let inherit (lib.importJSON ./flake.lock) nodes;
in lib.pipe nodes [
  (lib.filterAttrs (name: { flake ? name != "root", ... }: flake))
  (builtins.mapAttrs (name: { locked, ... }: builtins.flakeRefToString locked))
  (builtins.mapAttrs (_: builtins.getFlake))
]
