# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ modulesPath, config, pkgs, lib, inputs, ... }:

let
  emacs-overlay = inputs.emacs-overlay.overlay;
in

{
  imports = [
    "${modulesPath}/installer/cd-dvd/channel.nix"
    ../../nixos/modules/direnv
    ../../nixos/modules/yubikey-gpg
    ../../nixos/modules/vm-aarch64.nix
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

  hardware.yubikey-gpg = {
    enable = true;

    users = {
      sam.pinentryFlavor = "gtk2";
      root.pinentryFlavor = "curses";
    };
  };

  services.trezord.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;

  # Define your hostname.
  networking.hostName = "kimchi";

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
    chromium
    cabal2nix
    cntr
    docker
    docker-compose
    dmenu
    firefox
    feh
    ghc
    go-jira
    git
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
    spotify
    toxiproxy
    tree
    unzip
    vim
    wally-cli
    wireshark
    wget
    wireguard-tools
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
    alias limit='systemd-run --scope -p MemoryMax=500M -p CPUWeight=10 -p CPUQuota=600% --user'
  '';

  # List services that you want to enable:
  services.sshd.enable = true;
  programs.ssh.extraConfig = ''
  KexAlgorithms -sntrup761x25519-sha512@openssh.com
  '';

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  hardware.keyboard.zsa.enable = true;

  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = true;

  virtualisation.libvirtd.enable = true;
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
    # videoDrivers = ["nvidia"];

    # displayManager.defaultSession = "none+xmonad";
    desktopManager.xterm.enable = true;

    # windowManager.xmonad = {
    #   enable = true;
    #   enableContribAndExtras = true;
    # };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.extraUsers.sam = {
    createHome = true;
    extraGroups = ["wheel" "video" "audio" "disk" "networkmanager" "docker" "libvirtd" "dialout" "plugdev" "wireshark" ];
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

  users.extraUsers.cexplorer.isSystemUser = true;
  users.extraUsers.cexplorer.group = "cexplorer";
  users.groups.cexplorer = {};

  # virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "sam" ];

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

  nix.buildMachines = [
      # {
      #   hostName = "mac-mini-1";
      #   systems = [ "x86_64-darwin" ];
      #   maxJobs = 1;
      # }
    ];

  nix.settings.cores = 2;
  nix.settings.max-jobs = 4;

  nix = {
    # package = pkgs.nix_2_7;
    extraOptions = ''
      builders = @/etc/nix/machines
      builders-use-substitutes = true
      experimental-features = nix-command flakes
    '';
  };

  nix.settings.trusted-users = [ "root" "sam" "samuelbennett" ];

  nixpkgs.config.allowUnfree = true;

  services.vnstat.enable = true;

  # networking.firewall = {
  #   allowedUDPPorts = [ 51820 ]  # Wireguard
  #                  ++ [ 21027 ]; # syncthing
  #   allowedTCPPorts = [ 22000 ]; # syncthing
  # };
  # networking.wireguard.interfaces = {
  #   wg0 = {
  #     ips = [ "10.100.0.2/24" ];
  #     listenPort = 51820;

  #     generatePrivateKeyFile = true;
  #     privateKeyFile = "/etc/wireguard/wg0";

  #     peers = [
  #       {
  #         publicKey = "nUc1O2ASgcpDcov/T/LzSxleaH1TpW1vpdCofaSq9zw=";
  #         allowedIPs = [ "10.100.0.1/32" ];
  #         persistentKeepalive = 25;
  #         endpoint = "194.195.122.100:51820";
  #       }
  #       {
  #         publicKey = "qA6CoFU3os/v87e2PyYlAk6CpB/Rurk6v9F4/uOKc1U=";
  #         allowedIPs = [ "10.100.0.3/32" ];
  #         endpoint = "159.196.88.245:51820";
  #       }
  #     ];
  #   };
  # };

  # services.syncthing = {
  #   enable = true;
  #   overrideDevices = true;
  #   devices = {
  #     "server" = {
  #       id = "5HGYKKS-QQ7STUR-3DPAKBX-UUASJWW-Y437X52-NIHQ2BT-B4SUJBA-PDGD4QH";
  #       addresses = [ "tcp://server:22000" ];
  #       introducer = true;
  #     };
  #   };
  # };
}
