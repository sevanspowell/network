# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ modulesPath, config, pkgs, lib, inputs, ... }:

let
  nix-ll = inputs.self.packages."${pkgs.system}".nix-ll;

  emacs-overlay = inputs.emacs-overlay.overlay;
in

{
  imports = [
    "${modulesPath}/installer/cd-dvd/channel.nix"
    # ../../nixos/modules/direnv
    ../../nixos/modules/yubikey-gpg
    ../../nixos/modules/weechat
    ../../nixos/modules/vmware-guest.nix
  ];

  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "/nix/var/nix/profiles/per-user/root/channels"
    "nixos-config=/srv/network/nodes/${config.networking.hostName}/default.nix"
  ];

  # useGlobalPkgs/useUserPackages Required with flakes
  # See https://nix-community.github.io/home-manager/index.html#sec-flakes-nixos-module
  # and https://github.com/divnix/digga/issues/30
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  nixpkgs.overlays = [
    emacs-overlay
    (import ../../nixos/modules/home/emacs/emacs.nix)
  ];

  home-manager.users.dev = {...}: {

    home.stateVersion = "21.11";

    imports = [
      ../../nixos/modules/home/emacs
      ../../nixos/modules/home/xmobar
      ../../nixos/modules/home/xmonad
      ../../nixos/modules/home/xresources
      ../../nixos/modules/home/dunst
      ../../nixos/modules/home/git
    ];
  };

  hardware.yubikey-gpg = {
    enable = true;

    users = {
      dev.pinentryFlavor = "gtk2";
      root.pinentryFlavor = "curses";
    };
  };

  services.trezord.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "client"; # Define your hostname.

  # Select internationalisation properties.
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };
  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  # Set your time zone.
  time.timeZone = "Australia/Perth";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = (with pkgs; [
    cabal-install
    cabal2nix
    dmenu
    git
    nix-ll
    gnumake
    ledger
    libreoffice
    mitscheme
    mosh
    openssl
    openvpn
    pandoc
    pavucontrol
    patchutils
    pass
    ripgrep
    rofi
    rxvt_unicode-with-plugins
    silver-searcher
    toxiproxy
    tree
    unzip
    vim
    wally-cli
    wget
    wireguard
    xscreensaver
    zathura
  ]) ++
  (with pkgs.haskellPackages; [
    ghcid
    hasktags
    xmobar
  ]) ++ [];

  fonts.fonts = with pkgs; [
    fira-code
    iosevka
    hack-font
    hasklig
    meslo-lg
    source-code-pro
    noto-fonts-emoji
  ];

  environment.interactiveShellInit = ''
    alias ssh-iohk='ssh -F ~/.ssh/iohk.config'
    alias limit='systemd-run --scope -p MemoryMax=500M -p CPUWeight=10 -p CPUQuota=600% --user'
  '';

  # List services that you want to enable:
  services.sshd.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  hardware.keyboard.zsa.enable = true;

  services.postgresql = {
    enable = true;
    enableTCPIP = false;
  };

  networking.firewall.checkReversePath = false;

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip pkgs.epson-escpr2 ];
  services.avahi.enable = true;
  services.avahi.nssmdns = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    # layout = "us";
    # desktopManager.xterm.enable = false;
    xkbOptions="ctrl:nocaps";
    # displayManager.defaultSession = "none+xmonad";
    desktopManager.xterm.enable = true;

    # windowManager.xmonad = {
    #   enable = true;
    #   enableContribAndExtras = true;
    # };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.extraUsers.dev = {
    createHome = true;
    extraGroups = ["wheel" "video" "audio" "disk" "networkmanager" "docker" "libvirtd" "dialout" "plugdev" ];
    group = "users";
    home = "/home/dev";
    isNormalUser = true;
    uid = 1000;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425"
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425"
  ];

  nix.binaryCaches = [
    "https://cache.nixos.org"
    "https://cache.iog.io"
  ];
  nix.binaryCachePublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
  ];

  nix.buildCores = 2;
  nix.maxJobs = 4;

  nix = {
    package = pkgs.nix_2_7;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  nixpkgs.config.allowUnfree = true;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "21.11"; # Did you read the comment?

  networking.firewall = {
    allowedUDPPorts = [ 51820 ];  # Wireguard
  };
  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "10.100.0.4/24" ];
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
          publicKey = "qA6CoFU3os/v87e2PyYlAk6CpB/Rurk6v9F4/uOKc1U=";
          allowedIPs = [ "10.100.0.3/32" ];
          endpoint = "159.196.88.245:51820";
        }
      ];
    };
  };

  #networking.nameservers = [ "10.100.0.1" ];
}
