{ pkgs
, system
# , configuration
, partitionDiskScript
, diskSize ? (8 * 1024)
}:

let
  sources = import ../../nix/sources.nix;

  configuration = { config, modulesPath, ... }: {
    imports = [
      ../../nodes/plum/configuration.nix
      ../modules/qemu-vm-base.nix
      "${pkgs.callPackage ./vm-hardware-config.nix {
        inherit system diskSize partitionDiskScript;
      }}/hardware-configuration.nix"
      ../modules/copy-network-repo.nix
      {
        users.mutableUsers = false;
        users.extraUsers.sam.initialPassword = "";
        users.extraUsers.root.initialPassword = "";
      }
    ];

    hardware.enableAllFirmware = pkgs.lib.mkForce false;
    documentation.nixos.enable = false;

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
  ];

  installedConfig = machineConfig.config.system.build.toplevel;

in
  installerConfig.config.system.build.vm
