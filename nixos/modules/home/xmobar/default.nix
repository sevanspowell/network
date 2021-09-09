{ config, pkgs, ... }:

{
  home.file.".xmobarrc".source      = ./.xmobarrc;
}
