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
{
  vm = (vmConfig ./nodes/plum/configuration.nix).config.system.build.vm;
  iso = isoConfig.config.system.build.isoImage;
  install = installerEnv ./nodes/plum/configuration.nix;

  # nix-build -A tests.installer.x86_64-linux.test.driverInteractive
  tests = pkgs.callPackage ./nixos/tests/default.nix { inherit system; };

  hardware-config = pkgs.callPackage ./nixos/lib/vm-hardware-config.nix {
    inherit system partitionDiskScript;
  };

  # partition-disks && install-nixos
  # $ qemu-kvm -m 384 -netdev user,id=net0 -device virtio-net-pci,netdev=net0 $QEMU_OPTS -drive file=./nixos.qcow2,if=virtio,werror=report -cpu max -m 1024
  # <3
  installer-test-helper = pkgs.callPackage ./nixos/lib/vm-install-test.nix {
    inherit system partitionDiskScript;
  };
}
