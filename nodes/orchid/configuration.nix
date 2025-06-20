# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ modulesPath, config, pkgs, lib, inputs, ... }:

let
  # cardano-cli = inputs.cardano-node.packages.x86_64-linux.cardano-cli;
  # cardano-node = inputs.cardano-node.packages.x86_64-linux.cardano-node;

  linode-cli = inputs.self.packages.x86_64-linux.linode-cli;

  nix-ll = inputs.self.packages.x86_64-linux.nix-ll;

  emacs-overlay = inputs.emacs-overlay.overlay;
in

{
  imports = [
    "${modulesPath}/installer/cd-dvd/channel.nix"
    ../../nixos/modules/direnv
    ../../nixos/modules/yubikey-gpg

    # ../../nixos/modules/copy-network-repo.nix
    # ../../nixos/modules/gnome
    # ../../nixos/modules/weechat
  ];

  hardware.sane.enable = true;

  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "client";
  services.tailscale.extraUpFlags = [ "--ssh" ];

  services.arbtt.enable = true;
  services.arbtt.logFile = "/home/sam/.arbtt/capture.log";

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "/nix/var/nix/profiles/per-user/root/channels"
    "nixos-config=/srv/network/nodes/${config.networking.hostName}/default.nix"
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  sops.defaultSopsFile = ../../secrets/orchid.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets = {
    org_gcal_client_id = {
      owner = config.users.users.sam.name;
    };
    org_gcal_client_secret = {
      owner = config.users.users.sam.name;
    };
  };

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
      # ../../nixos/modules/home/chat
      ../../nixos/modules/home/offlineimap
    ];
  };

  hardware.yubikey-gpg = {
    enable = true;

    users = {
      sam.pinentryFlavor = "qt";
      root.pinentryFlavor = "curses";
    };
  };

  services.trezord.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 1;
  boot.loader.efi.canTouchEfiVariables = true;

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
    tailscale
    # cardano-cli
    # cardano-node
    cowsay
    lolcat
    termdown
    cabal-install
    chromium
    vulkan-tools
    cabal2nix
    cntr
    # dhcpcd
    # teams
    # docker
    # docker-compose
    dmenu
    firefox
    kdePackages.kdenlive
    # kicad
    feh
    ghc
    go-jira

    git
    git-annex
    git-annex-remote-rclone

    rclone
    nix-ll
    gnumake
    glxinfo
    renderdoc
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
    platformio
    ripgrep
    rofi
    rxvt-unicode
    silver-searcher
    spotify
    toxiproxy
    tlaplusToolbox
    tree
    unzip
    vulkan-validation-layers
    vim
    nix-prefetch-git
    wally-cli
    arandr
    wget
    (wine.override { mingwSupport = true; wineBuild = "wine64"; })
    wireguard-tools
    xscreensaver
    android-tools
    android-udev-rules
    zathura
    # podman-tui # status of containers in the terminal
    # podman-compose # start group of containers for dev
  ]) ++
  (with pkgs.haskellPackages; [
    ghcid
    hasktags
    xmobar
    arbtt
  ]) ++ [];

  fonts.packages = with pkgs; [
    fira-code
    iosevka
    hack-font
    hasklig
    meslo-lg
    source-code-pro
    noto-fonts-emoji
    jetbrains-mono
  ];

  environment.interactiveShellInit = ''
    alias ssh-iohk='ssh -F ~/.ssh/iohk.config'
    alias limit='systemd-run --scope -p MemoryMax=500M -p CPUWeight=10 -p CPUQuota=600% --user'
  '';

  # List services that you want to enable:
  services.sshd.enable = true;
  programs.ssh.extraConfig = ''
  KexAlgorithms -sntrup761x25519-sha512@openssh.com
  '';

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # services.cardano-node = {
  #   environment = "mainnet";
  #   enable = false;
  #   port = 3001;
  #   systemdSocketActivation = true;
  # };

  # services.cardano-db-sync = {
  #   enable = false;
  #   postgres = {
  #     database = "cexplorer";
  #     user = "cardano-node";
  #   };
  #   user = "cardano-node";
  #   cluster = "mainnet";
  #   extended = true;
  #   # environment = (import sources.iohk-nix {}).cardanoLib.environments.testnet;
  #   socketPath = config.services.cardano-node.socketPath;
  # };

  hardware.keyboard.zsa.enable = true;

  # services.postgresql = {
  #   enable = true;
  #   port = 5432;
  #   enableTCPIP = true;
  # #   settings = {
  # #     log_statement = "all";
  # #     max_connections = 200;
  # #     shared_buffers = "2GB";
  # #     effective_cache_size = "6GB";
  # #     maintenance_work_mem = "512MB";
  # #     checkpoint_completion_target = 0.7;
  # #     wal_buffers = "16MB";
  # #     default_statistics_target = 100;
  # #     random_page_cost = 1.1;
  # #     effective_io_concurrency = 200;
  # #     work_mem = "10485kB";
  # #     min_wal_size = "1GB";
  # #     max_wal_size = "2GB";
  # #   };
  # #   identMap = ''
  # #     explorer-users root cardano-node
  # #     explorer-users postgres postgres
  # #     explorer-users sam cardano-node
  # #     explorer-users cardano-node cexplorer
  # #     explorer-users cardano-node cardano-node
  # #     explorer-users root cexplorer
  # #     explorer-users sam cexplorer
  # #     explorer-users cexplorer cexplorer
  # #   '';
  #   package = pkgs.postgresql.withPackages (p: [ p.postgis ]);
  #   authentication = ''
  #     host all all all trust
  #   '';
  # #   ensureUsers = [
  # #     {
  # #       name = "cardano-node";
  # #       ensurePermissions = {
  # #         "DATABASE explorer_python_api" = "ALL PRIVILEGES";
  # #         "DATABASE cexplorer" = "ALL PRIVILEGES";
  # #         "DATABASE hdb_catalog" = "ALL PRIVILEGES";
  # #         "ALL TABLES IN SCHEMA public" = "ALL PRIVILEGES";
  # #       };
  # #     }
  # #     {
  # #       name = "cexplorer";
  # #       ensurePermissions = {
  # #         "DATABASE cexplorer" = "ALL PRIVILEGES";
  # #         "ALL TABLES IN SCHEMA information_schema" = "SELECT";
  # #         "ALL TABLES IN SCHEMA pg_catalog" = "SELECT";
  # #       };
  # #     }
  # #   ];
  # };

  virtualisation.libvirtd.enable = true;
  boot.kernelModules = [ "kvm-amd" "kvm-intel" ];
  boot.supportedFilesystems = [ "ntfs" ];

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip pkgs.epson-escpr2 ];
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;

  # Enable sound.
  # sound.enable = true;
  services.pulseaudio.enable = false;
  services.pulseaudio.support32Bit = true;

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    # layout = "us";
    # desktopManager.xterm.enable = false;
    xkb.options ="ctrl:nocaps";
    dpi = null;

    # displayManager.defaultSession = "none+xmonad";
    desktopManager.xterm.enable = true;
    videoDrivers = [ "modesetting" ];

    # windowManager.xmonad = {
    #   enable = true;
    #   enableContribAndExtras = true;
    # };

  };


  # hardware.opengl.driSupport = true;
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.graphics.extraPackages = [pkgs.mesa];
  hardware.nvidia.open = false;
  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.nvidiaSettings = true;
  nixpkgs.config.nvidia.acceptLicense = true;
  # Optionally, you may need to select the appropriate driver version for your specific GPU.
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy470;
  boot.kernelPackages = pkgs.linuxPackages_5_10;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.extraUsers.sam = {
    createHome = true;
    extraGroups = ["wheel" "video" "audio" "disk" "networkmanager" "docker" "libvirtd" "dialout" "plugdev" "wireshark" "scanner" "lp" "adbusers" "kvm" "podman"];
    group = "users";
    home = "/home/sam";
    isNormalUser = true;
    uid = 1000;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425"
    ];
  };

  programs.adb.enable = true;
  programs.wireshark.enable = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425"
  ];

  users.extraUsers.cexplorer.isSystemUser = true;
  users.extraUsers.cexplorer.group = "cexplorer";
  users.groups.cexplorer = {};

  # virtualisation.virtualbox.host.enable = true;
  # virtualisation.virtualbox.guest.enable = true;
  # virtualisation.virtualbox.guest.x11 = true;
  # users.extraGroups.vboxusers.members = [ "sam" ];

  nix.settings.substituters = [
    # "https://bucket.vpce-05447cd9b59749c2e-zm6zmqyb.s3.ap-southeast-2.vpce.amazonaws.com/cache.sambnt.io"
    "https://cache.nixos.org"
    # "https://iohk.cachix.org"
    "https://cache.iog.io"
    "https://nixcache.reflex-frp.org"
    # "https://cache.zw3rk.com"
  ];
  nix.settings.trusted-public-keys = [
    "cache.sambnt.io:juiSxv2kOyXiXZuwx4RHuYmyUCdYmbAYAKdzBtkM7mo="
    # "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    # "iohk.cachix.org-1:DpRUyj7h7V830dp/i6Nti+NEO2/nhblbov/8MW7Rqoo="
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    "ryantrinkle.com-1:JJiAKaRv9mWgpVAz8dwewnZe0AzzEAzPkagE9SP5NWI="
  ];

  nix.buildMachines = [
      {
        hostName = "mac-mini-1";
        systems = [ "x86_64-darwin" ];
        maxJobs = 1;
      }
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

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "20.09"; # Did you read the comment?

  services.vnstat.enable = true;

  networking.firewall = {
    allowedUDPPorts = [ 51820 ];  # Wireguard
  };
  networking.extraHosts = ''
    127.0.0.1 www.example.com api.example.com login.example.com
  '';
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

  programs.steam.enable = true;

  # services.postgresql = {
  #   enable = true;
  #   ensureDatabases = [ "cpd" "mulch" ];
  #   package = pkgs.postgresql_16;
  #   authentication = pkgs.lib.mkOverride 10 ''
  #     # Allow all local connections
  #     local all all trust
  #     # Allow all remote connections
  #     host all all all trust
  #   '';
  #   enableTCPIP = true;
  # };

  # Enable common container config files in /etc/containers

  # virtualisation.docker.enable = true;
  # virtualisation.docker.enableOnBoot = true;
  boot.enableContainers = false;
  virtualisation.containers.enable = true;
  virtualisation = {
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # Useful other development tools
  # environment.systemPackages = with pkgs; [
  #   dive # look into docker image layers
  #   podman-tui # status of containers in the terminal
  #   docker-compose # start group of containers for dev
  #   #podman-compose # start group of containers for dev
  # ];
}
