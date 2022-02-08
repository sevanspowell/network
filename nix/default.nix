{ system ? builtins.currentSystem
, config ? {}
}:
let
  sources = import ./sources.nix { inherit pkgs; };
  nixpkgs = sources.nixpkgs;

  iohkNix = import sources.iohk-nix {};

  # for inclusion in pkgs:
  overlays = [
    (self: super: {
      inherit sources;
      linode-cli = self.python3Packages.callPackage pkgs/linode-cli.nix {};
      inherit iohkNix;
    })
  ];

  pkgs = import nixpkgs {
    inherit system overlays config;
  };

in pkgs
