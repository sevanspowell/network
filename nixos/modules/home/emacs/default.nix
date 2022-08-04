{ config, pkgs, ... }:

let
  # emacsOverlay = import (builtins.fetchTarball {url = https://github.com/nix-community/emacs-overlay/archive/master.tar.gz;});
  emacsOverlay = import (builtins.fetchTarball {
    url = https://github.com/nix-community/emacs-overlay/archive/2293d3e1dcdebfc5c7de839dc9571df6a37c19c6.tar.gz;
    sha256 = "0px81s2s3ga1bg71da0j9nf1afmccsgmq2xb9wq1vdf3n77011ca";
  });

  emacsLocal = pkgs.emacsWithPackagesFromUsePackage {
    package = pkgs.emacs28;
    config = ./configuration.org;
    extraEmacsPackages = epkgs: [ epkgs.vterm epkgs.emacsql-sqlite ];
    alwaysEnsure = true;
    alwaysTangle = true;
    override = epkgs: epkgs // {
      direnv = epkgs.melpaPackages.direnv.overrideAttrs(old: {
        patches = [ ./remote-direnv.patch ];
      });
    };
  };
in

{
  nixpkgs.overlays = [
    emacsOverlay
    (import ./emacs.nix)
  ];

  home.packages = [
    pkgs.sqlite
    pkgs.source-code-pro
    pkgs.mu
  ];

  fonts.fontconfig.enable = pkgs.lib.mkForce true;

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
