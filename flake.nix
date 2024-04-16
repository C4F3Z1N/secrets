{
  description = "My secrets";
  inputs = {
    # deduplication;
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ flake-parts, nixpkgs, systems, treefmt-nix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ treefmt-nix.flakeModule ];

      perSystem = {
        treefmt.config = {
          programs.nixfmt.enable = true;
          programs.prettier.enable = true;
          projectRootFile = "flake.nix";
          settings.formatter.prettier.includes = [ "*.lock" ];
        };
      };

      systems = import systems;
    };
}
