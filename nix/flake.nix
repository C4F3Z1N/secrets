{
  description = "Hosts, services, users and their secrets pre-configured with sops-nix";

  inputs = {
    # deduplication;
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    sops-nix,
    systems,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      flake = {lib, ...}: {
        nixosConfigurations = import ./hosts.nix {inherit lib sops-nix;};
      };

      systems = import systems;
    };
}
