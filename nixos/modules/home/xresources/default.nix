
{ config, pkgs, ... }:

{
  xsession = {
    enable = true;

    windowManager.xmonad = {
      enable = true;
      enableContribAndExtras = true;
    };
    profileExtra = ''
      xrandr --output DVI-D-0 --off --output HDMI-0 --primary --mode 2560x1440 --pos 1920x0 --rotate normal --output DP-0 --mode 1920x1200 --pos 0x0 --rotate normal --output DP-1 --off --output DP-2 --off --output DP-3 --off --output DP-4 --off --output DP-5 --off
      feh --bg-fill ~/Downloads/nix-wallpaper-simple-dark-gray_bottom.png
    '';
  };

  services.xscreensaver.enable = true;

  xresources.properties = {
    # X config
    "Xcursor.size" = 2;
    # X screensaver
    "xscreensaver.mode" = "blank";
    # URxvt config
    "URxvt.scrollBar" = false;
    "URxvt.font" = "xft:DejaVu Sans Mono:pixelsize=12";
    "URxvt.internalBorder" = 8;
    "URxvt.pointerBlank" = true;
    "URxvt.saveLines" = 100000;
    # Font config
    "Xft.antialias" = true;
    "Xft.autohint" = false;
    "Xft.dpi" = 96;
    "Xft.hinting" = false;
    "Xft.hintstyle" = "hintslight";
    "Xft.lcdfilter" = "lcddefault";
    "Xft.rgba" = "rgb";
    # Other
    "xterm*metaSendsEscape" = true;
  };

  xresources.extraConfig = ''
    ! special
    *.foreground:   #b2b2b2
    *.background:   #1b1b1b
    *.cursorColor:  #ffffff

    ! black
    *.color0:       #3d3d3d
    *.color8:       #4d4d4d

    ! red
    *.color1:       #6673bf
    *.color9:       #899aff

    ! green
    *.color2:       #3ea290
    *.color10:      #52ad91

    ! yellow
    *.color3:       #b0ead9
    *.color11:      #98c9bb

    ! blue
    *.color4:       #31658c
    *.color12:      #477ab3

    ! magenta
    *.color5:       #596196
    *.color13:      #7882bf

    ! cyan
    *.color6:       #8292b2
    *.color14:      #95a7cc

    ! white
    *.color7:       #c8cacc
    *.color15:      #edeff2
  '';
}
