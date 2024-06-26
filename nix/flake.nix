{
  description = "My secrets";

  inputs = {
    # deduplication;
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ nixpkgs, ... }: {
    nixosModules = rec {
      default = secrets;
      secrets = import ./module.nix;
    };
  };
}
