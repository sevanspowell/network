# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ modulesPath, config, pkgs, lib, inputs, ... }:

let
  cardano-cli = inputs.cardano-node.packages.x86_64-linux.cardano-cli;

  linode-cli = inputs.self.packages.x86_64-linux.linode-cli;

  nix-ll = inputs.self.packages.x86_64-linux.nix-ll;

in

{
  imports = [
    "${modulesPath}/installer/cd-dvd/channel.nix"
    # ../../nixos/modules/copy-network-repo.nix
    ../../nixos/modules/direnv
    ../../nixos/modules/yubikey-gpg
    ../../nixos/modules/weechat
  ];

  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "/nix/var/nix/profiles/per-user/root/channels"
    "nixos-config=/srv/network/nodes/${config.networking.hostName}/default.nix"
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
      # ../../nixos/modules/home/chat
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
    # chromium
    cntr
    # dhcpcd
    docker
    docker-compose
    dmenu
    firefox
    feh
    ghc
    go-jira
    git
    linode-cli
    nix-ll
    gnumake
    ledger
    libreoffice
    mitscheme
    mosh
    # nixops
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
    alias ssh-iohk='ssh -F ~/.ssh/iohk.config'
    alias limit='systemd-run --scope -p MemoryMax=500M -p CPUWeight=10 -p CPUQuota=600% --user'
  '';

  # List services that you want to enable:
  services.sshd.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  services.cardano-node = {
    environment = "mainnet";
    enable = false;
    port = 3001;
    systemdSocketActivation = true;
  };

  services.cardano-db-sync = {
    enable = false;
    postgres = {
      database = "cexplorer";
      user = "cardano-node";
    };
    user = "cardano-node";
    cluster = "mainnet";
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
    videoDrivers = ["nvidia"];

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
  users.extraUsers.cexplorer.group = "cexplorer";
  users.groups.cexplorer = {};

  # virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "sam" ];

  nix.binaryCaches = [
    "https://sevanspowell-personal.cachix.org"
    "https://cache.nixos.org"
    "https://iohk.cachix.org"
    "https://cache.iog.io"
  ];
  nix.binaryCachePublicKeys = [
    "sevanspowell-personal.cachix.org-1:VOY8b19A+HGl1xUof+ucLFTDRCYBhjv+q94rxt5t5Bk="
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "iohk.cachix.org-1:DpRUyj7h7V830dp/i6Nti+NEO2/nhblbov/8MW7Rqoo="
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    # "mantis-ops.cachix.org-1:SornDcX8/9rFrpTjU+mAAb26sF8mUpnxgXNjmKGcglQ="
  ];

  nix.buildMachines = [
      {
        hostName = "mac-mini-1";
        systems = [ "x86_64-darwin" ];
        maxJobs = 1;
      }
    ];

  nix.buildCores = 2;
  nix.maxJobs = 4;

  nix = {
    package = pkgs.nix_2_7;
    extraOptions = ''
      builders = @/etc/nix/machines
      builders-use-substitutes = true
      experimental-features = nix-command flakes
    '';
  };

  nixpkgs.config.allowUnfree = true;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "20.09"; # Did you read the comment?

  services.vnstat.enable = true;

  networking.firewall = {
    allowedUDPPorts = [ 51820 ]  # Wireguard
                   ++ [ 21027 ]; # syncthing
    allowedTCPPorts = [ 22000 ]; # syncthing
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

  networking.nameservers = [ "10.100.0.1" ];

  services.syncthing = {
    enable = true;
    overrideDevices = true;
    devices = {
      "server" = {
        id = "5HGYKKS-QQ7STUR-3DPAKBX-UUASJWW-Y437X52-NIHQ2BT-B4SUJBA-PDGD4QH";
        addresses = [ "tcp://server:22000" ];
        introducer = true;
      };
    };
  };
}
