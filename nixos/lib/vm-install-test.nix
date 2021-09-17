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
  ];

  installedConfig = machineConfig.config.system.build.toplevel;

in
  installerConfig.config.system.build.vm
