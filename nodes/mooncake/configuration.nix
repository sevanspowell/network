{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./lib/gpg-passthru.nix
      ./lib/base.nix
      ./lib/dev.nix
    ];

  nix.nixPath =
    [
      "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
      "/nix/var/nix/profiles/per-user/root/channels"
      "nixos-config=/persist/srv/network/nodes/${config.networking.hostName}/default.nix"
    ];

  gpg-passthru.users = [ "dev" "root" ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/";

  # source: https://grahamc.com/blog/erase-your-darlings
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r rpool/local/root@blank
  '';

  # Set noop scheduler for zfs partitions
  services.udev.extraRules = ''
    ACTION="add|change", KERNEL=="sd[a-z]*[0-9]*|mmcblk[0-9]*p[0-9]*|nvme[0-9]*n[0-9]*p[0-9]*", ENV{ID_FS_TYPE}=="zfs_member", ATTR{../queue/scheduler}="none"
  '';

  networking.hostName = "mooncake";
  networking.hostId = "584e8d50";

  networking.useDHCP = false;
  networking.interfaces.enp0s31f6.useDHCP = true;

  environment.systemPackages = with pkgs;
    [
      vim
      emacs
      rxvt_unicode.terminfo
    ];

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
  };

  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
    passwordAuthentication = false;
    hostKeys =
      [
        {
          path = "/persist/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
        {
          path = "/persist/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
      ];
  };

  users = {
    mutableUsers = false;
    users = {
      root = {
        openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425" ];
      };
    };
  };

  networking.firewall = {
    allowedUDPPorts = [
      51820   # Wireguard
    ];
  };
  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "10.100.0.3/24" ];
      listenPort = 51820;

      generatePrivateKeyFile = true;
      privateKeyFile = "/persist/etc/wireguard/wg0";

      peers = [
        {
          publicKey = "nUc1O2ASgcpDcov/T/LzSxleaH1TpW1vpdCofaSq9zw=";
          allowedIPs = [ "10.100.0.1/32" ];
          persistentKeepalive = 25;
          endpoint = "194.195.122.100:51820";
        }
        {
          publicKey = "jCC29+Wpanv5kfx7sJqVnzOP5ToWc7FBgO1bJYcJqDY=";
          allowedIPs = [ "10.100.0.2/32" ];
        }
      ];
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

}
