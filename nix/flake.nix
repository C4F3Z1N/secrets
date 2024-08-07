{
  description = "Hosts and their secrets pre-configured with sops-nix";

  inputs.sops-nix.inputs = {
    nixpkgs-stable.follows = "nixpkgs";
    nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    nixpkgs,
    sops-nix,
    ...
  }: {
    nixosConfigurations = import ./hosts.nix {
      inherit (nixpkgs) lib;
      inherit sops-nix;
    };
  };
}
