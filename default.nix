{ pkgs ? import ./nix {},  system ? "x86_64-linux" }:

let
  nixpkgs = pkgs.lib.cleanSource pkgs.path;

  vmConfig = configuration: (import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system ;
    modules = [
      configuration
      "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
      "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
      {
        users.mutableUsers = false;
        users.extraUsers.sam.initialPassword = "sam";
      }
    ];
  });

  isoConfig = (import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
      "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    ];
  });

  installerEnv = configuration:
    let
      evaluated = import "${nixpkgs}/nixos/lib/eval-config.nix" {
        inherit system ;
        modules = [ configuration ];
      };

      isoImage = isoConfig.config.system.build.isoImage;
      isoName = isoConfig.config.isoImage.isoName;

      systemName = evaluated.config.system.name;

    in
      pkgs.writeShellScriptBin "run-${systemName}-vm" ''
        ${(vmConfig configuration).config.system.build.vm}/bin/run-${systemName}-vm -boot d -cdrom ${isoImage}/iso/${isoName}
      '';

  partitionDiskScript = import ./nixos/scripts/partition/simple.nix {
    inherit pkgs;
    disk = "/dev/vda";
  };
in
rec {
  vm = (vmConfig ./nodes/plum/configuration.nix).config.system.build.vm;
  iso = isoConfig.config.system.build.isoImage;
  install = installerEnv ./nodes/plum/configuration.nix;

  # nix-build -A tests.installer.x86_64-linux.test.driverInteractive
  tests = pkgs.callPackage ./nixos/tests/default.nix { inherit system; };

  hardware-config = pkgs.callPackage ./nixos/lib/vm-hardware-config.nix {
    inherit system partitionDiskScript;
  };

  # partition-disks && install-nixos
  # $ qemu-kvm -drive file=./nixos.qcow2,if=virtio,werror=report -cpu max -m 1024 -net nic,netdev=user.0,model=virtio -netdev user,id=user.0,hostfwd=tcp::2221-:22,hostfwd=tcp::8080-:80 -soundhw all
  # $ ssh -X -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no sam@localhost -p 2221
  # <3
  installer-test-helper = pkgs.callPackage ./nixos/lib/vm-install-test.nix {
    inherit system partitionDiskScript;
    diskSize = 25 * 1024;
  };

  # Rebuild on system:
  # pathToConfig=$(nix-build --no-out-link -A nodes.plum.config.system.build.toplevel)
  # nix-env -p /nix/var/nix/profiles/system --set $pathToConfig
  # $pathToConfig/bin/switch-to-configuration switch

  nodes = {
    plum = (import "${nixpkgs}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [
        ./nodes/plum/configuration.nix
        ./nixos/modules/qemu-vm-base.nix
        "${pkgs.callPackage ./nixos/lib/vm-hardware-config.nix {
          diskSize = 25 * 1024;
          inherit system partitionDiskScript;
        }}/hardware-configuration.nix"
        {
          boot.loader.grub.device = "/dev/vda";
        }
      ];
    });
  };
}
