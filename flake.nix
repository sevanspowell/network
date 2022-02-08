{
  description = "Network";

  inputs = {
    cardano-db-sync.url = "github:input-output-hk/cardano-db-sync?ref=refs/tags/12.0.0";
    cardano-node.url = "github:input-output-hk/cardano-node?ref=refs/tags/1.33.0";
    deploy.url = "github:input-output-hk/deploy-rs";
    flake-utils.url = "github:numtide/flake-utils";
    haskellNix.url = "github:input-output-hk/haskell.nix";
    home-manager.url = "github:nix-community/home-manager/release-21.11";
    nix.url = "github:NixOS/nix/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
  };
  outputs = { ... } @ args: import ./outputs.nix args;
}
