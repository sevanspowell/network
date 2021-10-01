{ config, pkgs, lib, ... }:

let
  sources = import ../../nix/sources.nix;
in
{
  imports = [
    "${sources.home-manager}/nixos"
    ../../nixos/modules/copy-network-repo.nix
    ../../nixos/modules/yubikey-gpg
    # ../../nixos/modules/direnv
  ];

  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "/nix/var/nix/profiles/per-user/root/channels"
    "nixos-config=/srv/network/nodes/plum"
  ];

  home-manager.users.sam = {...}: {
    imports = [
      ../../nixos/modules/home/emacs
      ../../nixos/modules/home/xmobar
      ../../nixos/modules/home/xmonad
      ../../nixos/modules/home/xresources
      ../../nixos/modules/home/git
    ];
  };

  hardware.yubikey-gpg = {
    enable = true;

    users = {
      sam.pinentryFlavor = "gtk2";
      root.pinentryFlavor = "curses";
    };
  };

  # services.trezord.enable = true;

  networking.hostName = "plum";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };
  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  time.timeZone = "Australia/Perth";

  environment.systemPackages = (with pkgs; [
    firefox
    rofi
    pass
    ripgrep
    git
    rxvt_unicode-with-plugins
    silver-searcher
    usbutils
    tree
    unzip
    wget
    vim
    xscreensaver
  ]) ++
  (with pkgs.haskellPackages; [
    ghcid
    hasktags
    xmobar
  ]);

  fonts.fonts = with pkgs; [
    source-code-pro
  ];

  services.sshd.enable = true;
  services.openssh.enable = true;

  services.postgresql = {
    enable = true;
    enableTCPIP = false;
  };

  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

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

  users.extraUsers.sam = {
    createHome = true;
    extraGroups = ["wheel" "video" "audio" "disk" "networkmanager" "plugdev" ];
    group = "users";
    home = "/home/sam";
    isNormalUser = true;
    uid = 1000;
  };

  nix.binaryCaches = [
    "https://sevanspowell-personal.cachix.org"
    "https://cache.nixos.org"
    "https://iohk.cachix.org"
    "https://hydra.iohk.io"
  ];
  nix.binaryCachePublicKeys = [
    "sevanspowell-personal.cachix.org-1:VOY8b19A+HGl1xUof+ucLFTDRCYBhjv+q94rxt5t5Bk="
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "iohk.cachix.org-1:DpRUyj7h7V830dp/i6Nti+NEO2/nhblbov/8MW7Rqoo="
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
  ];

  nixpkgs.config.allowUnfree = true;
}
