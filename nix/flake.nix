{
  description = "Hosts and their secrets pre-configured with sops-nix";

  inputs = {
    # deduplication;
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {nixpkgs, ...}: {};
}
