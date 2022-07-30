{ config, pkgs, lib, ... }:

{
  imports =
    [
    ];

  nix.nixPath =
    [
      "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
      "/nix/var/nix/profiles/per-user/root/channels"
      "nixos-config=/persist/srv/network/nodes/${config.networking.hostName}/default.nix"
    ];

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
    ];

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
  };

  services.openssh = {
    enable = true;
    permitRootLogin = "no";
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
      root = { };

      dev = {
        createHome = true;
	      extraGroups = [ "wheel" ];
	      group = "users";
	      uid = 1000;
	      home = "/home/dev";
	      useDefaultShell = true;
        openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425" ];
        isNormalUser = true;
	      initialHashedPassword = "\$6\$UkLbKtZhBqWyLqva\$kFIDxCtQ7XpF0hvTA6uSDgkTaEqDYtWOcPoBPZPXLuasr2MKtp9qU59ah4w.kuC3vsl5F9xJpyLFj5s5m/Paq/";
      };
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
