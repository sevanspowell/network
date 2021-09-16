{ pkgs
, system
# , configuration
, partitionDiskScript
, diskSize ? (8 * 1024)
}:

let
  configuration = { modulesPath, ... }: {
    imports = [
      "${modulesPath}/testing/test-instrumentation.nix"
      "${modulesPath}/profiles/qemu-guest.nix"
      "${modulesPath}/profiles/minimal.nix"
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

    # fileSystems."/" =
    #   { device = "/dev/mapper/nixos--vg-root";
    #     fsType = "ext4";
    #   };

    # fileSystems."/boot" =
    #   { device = "/dev/disk/by-label/boot";
    #     fsType = "vfat";
    #   };

    # swapDevices =
    #   [ { device = "/dev/mapper/nixos--vg-swap"; }
    #   ];

    systemd.services.backdoor.conflicts = [ "sleep.target" ];

    powerManagement.resumeCommands = "systemctl --no-block restart backdoor.service";

    boot.loader.grub.device = "/dev/vda";

    fileSystems = {
      "/".device = "/dev/vda2";
    };
    swapDevices = pkgs.lib.mkOverride 0 [ { device = "/dev/vda1"; } ];
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
        partitionDiskScript
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
  ];

  installedConfig = machineConfig.config.system.build.toplevel;

  x = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
    inherit (pkgs) lib;
    inherit pkgs;
    additionalSpace = "1024M";
    # pkgs = import ../../../.. { inherit (pkgs) system; }; # ensure we use the regular qemu-kvm package
    format = "qcow2";
    config = machineConfig.config;
  };

  w = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
    inherit (pkgs) lib;
    inherit pkgs;
    additionalSpace = "1024M";
    # pkgs = import ../../../.. { inherit (pkgs) system; }; # ensure we use the regular qemu-kvm package
    format = "qcow2";
    config = (evalConfig [
      ({ modulesPath, ... }: {
        imports =
          [ "${modulesPath}/installer/cd-dvd/channel.nix"
            "${modulesPath}/virtualisation/openstack-config.nix"
          ];
      })
    ]).config;
  };

in
  installerConfig.config.system.build.vm
  # x
  # w
