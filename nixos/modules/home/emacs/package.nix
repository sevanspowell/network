{ config, pkgs, ... }:

pkgs.emacsWithPackagesFromUsePackage {
  package = pkgs.emacs-unstable;
  config = ./configuration.org;
  extraEmacsPackages = epkgs: [ epkgs.vterm epkgs.emacsql-sqlite pkgs.mu ];
  alwaysEnsure = true;
  alwaysTangle = true;
  override = epkgs: epkgs // {
  };
}
