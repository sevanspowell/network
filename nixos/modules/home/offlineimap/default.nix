{ config, pkgs, ... }:

{
  home.packages = [
    pkgs.offlineimap
  ];

  home.file.".offlineimaprc".source  = ./.offlineimaprc;
  home.file.".offlineimap.py".source = ./.offlineimap.py;
}
