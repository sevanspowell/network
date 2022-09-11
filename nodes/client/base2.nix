{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  nix.nixPath =
    [
      "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
      "nixos-config=/persist/etc/nixos/configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/";

  # source: https://grahamc.com/blog/erase-your-darlings
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r rpool/local/root@blank
    zfs rollback -r rpool/local/home@blank
  '';

  # Set noop scheduler for zfs partitions
  services.udev.extraRules = ''
    ACTION="add|change", KERNEL=="sd[a-z]*[0-9]*|mmcblk[0-9]*p[0-9]*|nvme[0-9]*n[0-9]*p[0-9]*", ENV{ID_FS_TYPE}=="zfs_member", ATTR{../queue/scheduler}="none"
  '';

  networking.hostId = "4eced986";

  networking.useDHCP = false;
  # networking.interfaces.enp3s0.useDHCP = true;

  environment.systemPackages = with pkgs;
    [
      emacs
      vim
      git
    ];

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
    # TODO: autoReplication
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
      root = {
        initialHashedPassword = "\$6\$OIyU7EGc/fS8bXtR\$GzC/UjZeux0j2pV2/m6W.LIPYUg6VQMYplS8EaAzZhpgvAEjF1QdR4EYWDCsokY8DFi9La5IkWut1mGux99QE0";
      };

      dev = {
        createHome = true;
	extraGroups = [ "wheel" ];
	group = "users";
	uid = 1000;
	home = "/home/dev";
	useDefaultShell = true;
        openssh.authorizedKeys.keys = [ "ssh-ed25519" ];
        isNormalUser = true;
        initialHashedPassword = "\$6\$v8973Kad7umMUV0e\$VPLTBLbEY26Q2Wq.R0.9wmKnE.THhJyb0HV6cEXTkFzFMh8MoTbYkuU.fq.MlaPyyjT.XEbhLJF5U0IOBwdVN1";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "L+ /etc/machine-id - - - - /persist/etc/machine-id"
    "d /home/dev 750 dev users - -"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
