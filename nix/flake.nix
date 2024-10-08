{
  description = "Personalized abstraction of secrets using sops-nix";

  inputs = {
    # deduplication;
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {nixpkgs, ...}: {
    nixosModules = rec {
      default = secrets;
      secrets = import ./module.nix;
    };
  };
}
