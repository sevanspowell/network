# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ modulesPath, config, pkgs, lib, ... }:

let
  sources = import ../../nix/sources.nix;

  cardano-cli = (import sources.cardano-node {}).cardano-cli;

  linode-cli = (import ../../nix {}).linode-cli;
in

{
  imports = [
    "${modulesPath}/installer/cd-dvd/channel.nix"
    "${sources.home-manager}/nixos"
    ../../nixos/modules/copy-network-repo.nix
    ../../nixos/modules/direnv
    ../../nixos/modules/yubikey-gpg
    ../../nixos/modules/weechat
    "${sources.cardano-node}/nix/nixos"
    "${sources.cardano-db-sync}/nix/nixos"
  ];

  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "/nix/var/nix/profiles/per-user/root/channels"
    "nixos-config=/srv/network/nodes/${config.networking.hostName}/default.nix"
  ];

  home-manager.users.sam = {...}: {
    imports = [
      ../../nixos/modules/home/emacs
      ../../nixos/modules/home/xmobar
      ../../nixos/modules/home/xmonad
      ../../nixos/modules/home/xresources
      ../../nixos/modules/home/dunst
      ../../nixos/modules/home/git
      ../../nixos/modules/home/chat
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

  networking.hostName = "orchid"; # Define your hostname.

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
    cardano-cli
    cabal-install
    cabal2nix
    chromium
    cntr
    # dhcpcd
    docker
    dmenu
    firefox
    feh
    ghc
    go-jira
    git
    linode-cli
    gnumake
    ledger
    libreoffice
    mitscheme
    mosh
    nixops
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
    tlaplusToolbox
    tree
    unzip
    vim
    wally-cli
    wget
    (wine.override { mingwSupport = true; wineBuild = "wine64"; })
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
    alias dropbox="docker exec -it dropbox dropbox"
    alias dropbox-start="docker run -d --restart=always --name=dropbox \
      -v /home/sam/Dropbox:/dbox/Dropbox \
      -v /home/sam/.dropbox:/dbox/.dropbox \
      -e DBO_UID=1000 -e DBOX_GID=100 janeczku/dropbox"
    alias ssh-iohk='ssh -F ~/.ssh/iohk.config'
  '';

  # # List services that you want to enable:
  services.sshd.enable = true;

  # # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    permitRootLogin = "without-password";
  };

  services.cardano-node = {
    environment = "testnet";
    enable = true;
    port = 3001;
    systemdSocketActivation = true;
  };

  services.cardano-db-sync = {
    enable = true;
    postgres = {
      database = "cexplorer";
      user = "cardano-node";
    };
    user = "cardano-node";
    cluster = "testnet";
    extended = true;
    # environment = (import sources.iohk-nix {}).cardanoLib.environments.testnet;
    socketPath = config.services.cardano-node.socketPath;
  };

  hardware.keyboard.zsa.enable = true;

  services.postgresql = {
    enable = true;
    enableTCPIP = false;
    settings = {
      max_connections = 200;
      shared_buffers = "2GB";
      effective_cache_size = "6GB";
      maintenance_work_mem = "512MB";
      checkpoint_completion_target = 0.7;
      wal_buffers = "16MB";
      default_statistics_target = 100;
      random_page_cost = 1.1;
      effective_io_concurrency = 200;
      work_mem = "10485kB";
      min_wal_size = "1GB";
      max_wal_size = "2GB";
    };
    identMap = ''
      explorer-users root cardano-node
      explorer-users postgres postgres
      explorer-users sam cardano-node
      explorer-users cardano-node cexplorer
      explorer-users cardano-node cardano-node
      explorer-users root cexplorer
      explorer-users sam cexplorer
      explorer-users cexplorer cexplorer
    '';
    authentication = ''
      local all all ident map=explorer-users
      local all all trust
    '';
    ensureDatabases = [
      "explorer_python_api"
      "cexplorer"
      "hdb_catalog"
    ];
    ensureUsers = [
      {
        name = "cardano-node";
        ensurePermissions = {
          "DATABASE explorer_python_api" = "ALL PRIVILEGES";
          "DATABASE cexplorer" = "ALL PRIVILEGES";
          "DATABASE hdb_catalog" = "ALL PRIVILEGES";
          "ALL TABLES IN SCHEMA public" = "ALL PRIVILEGES";
        };
      }
      {
        name = "cexplorer";
        ensurePermissions = {
          "DATABASE cexplorer" = "ALL PRIVILEGES";
          "ALL TABLES IN SCHEMA information_schema" = "SELECT";
          "ALL TABLES IN SCHEMA pg_catalog" = "SELECT";
        };
      }
    ];
    initialScript = pkgs.writeText "init.sql" ''
      CREATE USER sam WITH SUPERUSER;
      CREATE USER cexplorer WITH SUPERUSER;
      CREATE USER cardano-node WITH SUPERUSER;
      CREATE USER root WITH SUPERUSER;
      CREATE DATABASE sam WITH OWNER sam;
    '';
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = true;

  virtualisation.libvirtd.enable = true;
  networking.firewall.checkReversePath = false;

  # # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];

  # # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    # layout = "us";
    # desktopManager.xterm.enable = false;
    xkbOptions="ctrl:nocaps";
    videoDrivers = ["nvidia"];

    # displayManager.defaultSession = "none+xmonad";

    # windowManager.xmonad = {
    #   enable = true;
    #   enableContribAndExtras = true;
    # };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.sam = {
    createHome = true;
    extraGroups = ["wheel" "video" "audio" "disk" "networkmanager" "docker" "libvirtd" "dialout" "plugdev" ];
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

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "sam" ];

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
    # "mantis-ops.cachix.org-1:SornDcX8/9rFrpTjU+mAAb26sF8mUpnxgXNjmKGcglQ="
  ];

  nix = {
    package = pkgs.nixUnstable; # or versioned attributes like nix_2_4
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  nixpkgs.config.allowUnfree = true;

  # # This value determines the NixOS release with which your system is to be
  # # compatible, in order to avoid breaking some software such as database
  # # servers. You should change this only after NixOS release notes say you
  # # should.
  system.stateVersion = "18.09"; # Did you read the comment?

  services.vnstat.enable = true;

  # networking.nat = {
  #   enable = true;
  #   externalInterface = "
  # };

  networking.firewall = {
    enable = true;

    allowedUDPPorts = [ 51820 ];
    allowedTCPPorts = [ 22 ];

    interfaces.wg0.allowedUDPPorts = [ 22 ];
    interfaces.wg0.allowedTCPPorts = [ 22 ];
  };
  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "10.100.0.2/24" ];
      listenPort = 51820;

      generatePrivateKeyFile = true;
      privateKeyFile = "/etc/wireguard/wg0";

      peers = [
        {
          publicKey = "nUc1O2ASgcpDcov/T/LzSxleaH1TpW1vpdCofaSq9zw=";
          allowedIPs = [ "10.100.0.1/32" ];
          persistentKeepalive = 25;
          endpoint = "194.195.122.100:51820";
        }
      ];
    };
  };

  # networking.networkmanager.insertNameservers = [ "10.100.0.1" ];
  networking.nameservers = [ "10.100.0.1" ];

  services.syncthing = {
    enable = true;
  };
}
