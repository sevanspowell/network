{ config, pkgs, ... }:

let
  emacsOverlay = import (builtins.fetchTarball {url = https://github.com/nix-community/emacs-overlay/archive/master.tar.gz;});
  emacsLocal = pkgs.emacsWithPackagesFromUsePackage {
    config = ./configuration.org;
    extraEmacsPackages = epkgs: [ epkgs.vterm epkgs.emacsql-sqlite ];
    alwaysEnsure = true;
    alwaysTangle = true;
  };
in

{
  nixpkgs.overlays = [ emacsOverlay ];

  home.packages = [
    pkgs.sqlite
  ];

  programs.emacs = {
    enable = true;
    package = emacsLocal;
  };

  home.file.".emacs.d/init.el".source           = ./init.el;
  home.file.".emacs.d/configuration.org".source = ./configuration.org;
  home.file.".emacs.d/configuration.el".source =
    pkgs.runCommand "tangle-configuration"
      { buildInputs = [ emacsLocal pkgs.coreutils ]; }
      ''
        emacs --batch --eval "(require 'org)" --eval '(org-babel-tangle-file "${./configuration.org}" (getenv "out"))'
      '';
}
