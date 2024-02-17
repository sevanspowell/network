{
  description = "Network";

  inputs = {
    deploy.url = "github:input-output-hk/deploy-rs";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix.url = "github:NixOS/nix/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    haskellNix = {
      url = "github:input-output-hk/haskell.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
  }
;
  outputs = { ... } @ args: import ./outputs.nix args;
}
