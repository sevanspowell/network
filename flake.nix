{
  description = "Network";

  inputs = {
    cardano-db-sync.url = "github:input-output-hk/cardano-db-sync?ref=refs/tags/12.0.0";
    cardano-node.url = "github:input-output-hk/cardano-node?ref=refs/tags/1.35.2";
    deploy.url = "github:input-output-hk/deploy-rs";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager/release-21.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix.url = "github:NixOS/nix/master";
    nixpkgs.follows = "haskellNix/nixpkgs-2111";
    haskellNix = {
      url = "github:input-output-hk/haskell.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
  };
  outputs = { ... } @ args: import ./outputs.nix args;
}
