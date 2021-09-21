{ pkgs
, system
# , configuration
, partitionDiskScript
, diskSize ? (8 * 1024)
}:

let
  sources = import ../../nix/sources.nix;

  src = pkgs.lib.cleanSource ../..;
  srcPkg = pkgs.runCommand "copy-network-repo" {} ''
    mkdir $out
    cp -r ${src}/* $out
  '';

  configuration = { config, modulesPath, ... }: {
    imports = [
      # "${modulesPath}/testing/test-instrumentation.nix"
      "${modulesPath}/profiles/qemu-guest.nix"
      "${modulesPath}/profiles/minimal.nix"
      # ../../nodes/plum/configuration.nix
      {
        users.mutableUsers = false;
        users.extraUsers.sam.initialPassword = "";
        users.extraUsers.sam = {
          createHome = true;
          extraGroups = ["wheel" "video" "audio" "disk" "networkmanager" "plugdev" ];
          group = "users";
          home = "/home/sam";
          isNormalUser = true;
          uid = 1000;
        };
        users.extraUsers.root.initialPassword = "";
      }
      {
        environment.systemPackages = [ srcPkg ];

        boot.postBootCommands = ''
          echo ${srcPkg} > /root/src.out
        '';
      }
      {
        imports = [
          "${sources.home-manager}/nixos"
        ];

        home-manager.users.sam = {...}: {
          imports = [
            ../../nixos/modules/home/emacs
            ../../nixos/modules/home/xmobar
            ../../nixos/modules/home/xmonad
            ../../nixos/modules/home/xresources
          ];
        };

        environment.systemPackages = (with pkgs; [
          git
          rxvt_unicode-with-plugins
          vim
          srcPkg
          xscreensaver
        ]) ++
        (with pkgs.haskellPackages; [
          xmobar
        ]);

        networking.hostName = "plum";
        console = {
          font = "Lat2-Terminus16";
          keyMap = "us";
        };
        i18n = {
          defaultLocale = "en_US.UTF-8";
        };
        time.timeZone = "Australia/Perth";
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
      }
      {
        # Don't run ntpd in the guest.  It should get the correct time from KVM.
        services.timesyncd.enable = false;

        # When building a regular system configuration, override whatever
        # video driver the host uses.
        services.xserver.videoDrivers = pkgs.lib.mkVMOverride [ "modesetting" ];
        services.xserver.defaultDepth = pkgs.lib.mkVMOverride 0;
        services.xserver.resolutions = pkgs.lib.mkVMOverride [ { x = 1024; y = 768; } ];
        services.xserver.monitorSection =
          ''
          # Set a higher refresh rate so that resolutions > 800x600 work.
          HorizSync 30-140
          VertRefresh 50-160
          '';


        # Wireless won't work in the VM.
        networking.wireless.enable = pkgs.lib.mkVMOverride false;
        services.connman.enable = pkgs.lib.mkVMOverride false;

        # Speed up booting by not waiting for ARP.
        networking.dhcpcd.extraConfig = "noarp";

        networking.usePredictableInterfaceNames = false;

        system.requiredKernelConfig = with config.lib.kernelConfig;
          [ (isEnabled "VIRTIO_BLK")
            (isEnabled "VIRTIO_PCI")
            (isEnabled "VIRTIO_NET")
            (isEnabled "EXT4_FS")
            (isEnabled "NET_9P_VIRTIO")
            (isEnabled "9P_FS")
            (isYes "BLK_DEV")
            (isYes "PCI")
            (isYes "NETDEVICES")
            (isYes "NET_CORE")
            (isYes "INET")
            (isYes "NETWORK_FILESYSTEMS")
          ];
      }
    ];

    hardware.enableAllFirmware = pkgs.lib.mkForce false;
    documentation.nixos.enable = false;

    # boot.loader.grub.device = "nodev";
    # boot.loader.grub.efiSupport = true;
    # boot.loader.grub.efiInstallAsRemovable = true;

    # boot.loader.systemd-boot.enable = true;
    # boot.initrd.luks.devices = {
    #   nixos-enc = {
    #     device = "/dev/vda1";
    #     preLVM = true;
    #   };
    # };
    # boot.kernelParams = pkgs.lib.mkAfter [ "console=tty0" ];

    boot.loader.grub.device = "/dev/vda";
  };

  nixpkgs = pkgs.lib.cleanSource pkgs.path;

  # Configuration for "installer" machine
  installerConfiguration = import ../modules/installer-vm {
    inherit diskSize;
  };

  evalConfig = modules: import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system modules;
  };

  installerConfig = evalConfig [
    installerConfiguration
    ({ config, ...}: {
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "partition-disks" partitionDiskScript)
        (pkgs.writeShellScriptBin "install-nixos" ''
          nixos-install --root /mnt --system ${installedConfig} --no-root-passwd
        '')
      ];
      boot.postBootCommands = ''
        ${config.nix.package.out}/bin/nix-store --load-db ${pkgs.closureInfo { rootPaths = [ installedConfig ]; }}/registration
      '';
    })
  ];

  machineConfig = evalConfig [
    configuration
    "${pkgs.callPackage ./vm-hardware-config.nix {
      inherit system diskSize partitionDiskScript;
    }}/hardware-configuration.nix"
    # I think XLibs are disabled because we're presuming that this won't be
    # executed in a graphical environment. But we might do, and it causes some
    # graphical applications to fail to build, which prevents us from testing
    # our configurations.
    {
      environment.noXlibs = pkgs.lib.mkForce false;
    }
  ];

  installedConfig = machineConfig.config.system.build.toplevel;

in
  installerConfig.config.system.build.vm
