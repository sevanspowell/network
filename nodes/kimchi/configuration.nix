{ config, pkgs, modulesPath, inputs, ... }:

let
  emacs-overlay = inputs.emacs-overlay.overlay;
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../nixos/modules/vm-aarch64.nix
      "${modulesPath}/installer/cd-dvd/channel.nix"
      ../../nixos/modules/direnv
      ../../nixos/modules/yubikey-gpg
    ];

  hardware.yubikey-gpg = {
    enable = true;

    users = {
      sam.pinentryFlavor = "gtk2";
      root.pinentryFlavor = "curses";
    };
  };

  users.extraUsers.sam = {
    createHome = true;
    extraGroups = ["wheel" "video" "audio" "disk" "networkmanager" "docker" "libvirtd" "dialout" "plugdev" "wireshark"];
    group = "users";
    home = "/home/sam";
    isNormalUser = true;
    uid = 1000;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425"
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425"
  ];

  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "/nix/var/nix/profiles/per-user/root/channels"
    "nixos-config=/srv/network/nodes/${config.networking.hostName}/default.nix"
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  nixpkgs.overlays = [
    emacs-overlay
  ];

  environment.systemPackages = (with pkgs; [
    vim
    rxvt_unicode-with-plugins
    ripgrep
    git
    feh
    rofi
    tree
    unzip
    wireshark
    wireguard-tools
    xscreensaver
  ]) ++ (with pkgs.haskellPackages; [
    xmobar
  ]);

  fonts.fonts = with pkgs; [
    fira-code
    source-code-pro
    noto-fonts-emoji
  ];

  home-manager.users.sam = {...}: {
    home.stateVersion = "21.11";
  
    imports = [
      ../../nixos/modules/home/emacs
      ../../nixos/modules/home/xmobar
      ../../nixos/modules/home/xmonad
      ../../nixos/modules/home/xresources
      ../../nixos/modules/home/dunst
      ../../nixos/modules/home/git
      ../../nixos/modules/home/offlineimap
    ];
  };

  networking.hostName = "kimchi";

  services.sshd.enable = true;
  services.openssh.enable = true;
  hardware.keyboard.zsa.enable = true;


  console = {
    keyMap = "us";
  };

  time.timeZone = "Australia/Perth";

  services.xserver = {
    enable = true;
    desktopManager.xterm.enable = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5;

  nix.settings.substituters = [
    "https://cache.sitewisely.io"
    "https://cache.nixos.org"
    "https://cache.iog.io"
    "https://nixcache.reflex-frp.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.sitewisely.io:lszR3kpF1eDWYi8IxMrcu5a11T2HZ0x8yPgpVvqZm5M="
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    "ryantrinkle.com-1:JJiAKaRv9mWgpVAz8dwewnZe0AzzEAzPkagE9SP5NWI="
  ];

  nix.buildMachines = [ ];

  nix.settings.cores = 2;
  nix.settings.max-jobs = 4;

  nix = {
    extraOptions = ''
      builders = @/etc/nix/machines
      builders-use-substitutes = true
      experimental-features = nix-command flakes
    '';
  };

  nix.settings.trusted-users = [ "root" "sam" ];

  environment.interactiveShellInit = ''
    alias limit='systemd-run --scope -p MemoryMax=500M -p CPUWeight=10 -p CPUQuota=600% --user'
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}

