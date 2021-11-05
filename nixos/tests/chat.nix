{ config, pkgs, system, lib, ... }:
{
  name = "boot";

  nodes = {
    client = { modulesPath, ...}: {
      imports = [
        "${modulesPath}/installer/cd-dvd/channel.nix"
        "${pkgs.sources.home-manager}/nixos"
      ];

      boot.kernelParams = [
        "console=ttyS0,115200"
        "console=tty1"
      ];

      users.extraUsers.sam = {
        createHome = true;
        extraGroups = ["wheel" "video" "audio" "disk" "networkmanager" "plugdev" ];
        group = "users";
        home = "/home/sam";
        isNormalUser = true;
        uid = 1000;
      };

      users.extraUsers.sam.initialPassword = "";
      users.extraUsers.root.initialPassword = "";

      environment.systemPackages = [
        pkgs.fractal
      ];

      services.xserver = {
        enable = true;
        layout = "us";
        desktopManager.xterm.enable = false;
        xkbOptions="ctrl:nocaps";

        displayManager.defaultSession = "none+xmonad";

        windowManager.xmonad = {
          enable = true;
          enableContribAndExtras = true;
        };
      };

      home-manager.users.sam = {...}: {
        imports = [
          ../modules/home/chat
          ../modules/home/emacs
          ../modules/home/xmobar
          ../modules/home/xmonad
          ../modules/home/xresources
        ];
      };
    };
  };

  testScript =
    ''
        start_all()
    '';
}
