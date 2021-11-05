{ system ? builtins.currentSystem
, config ? {}
}:
let
  sources = import ./sources.nix { inherit pkgs; };
  nixpkgs = sources.nixpkgs;

  # for inclusion in pkgs:
  overlays = [
    (pkgs: _: {
      inherit sources;
    })
  ];

  pkgs = import nixpkgs {
    inherit system overlays config;
  };

in pkgs
