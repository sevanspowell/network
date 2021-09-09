{ config, pkgs, ... }:

{
  home.file.".xmonad/xmonad.hs".source     = ./xmonad.hs;
  home.file.".xmonad/lib/MyKeys.hs".source = ./lib/MyKeys.hs;
}
