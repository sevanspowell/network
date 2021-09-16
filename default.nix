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
in
{
  vm = (vmConfig ./nodes/plum/configuration.nix).config.system.build.vm;
  iso = isoConfig.config.system.build.isoImage;
  install = installerEnv ./nodes/plum/configuration.nix;

  # nix-build -A tests.installer.x86_64-linux.test.driverInteractive
  tests = pkgs.callPackage ./nixos/tests/default.nix { inherit system; };

  hardware-config = pkgs.callPackage ./nixos/lib/vm-hardware-config.nix {
    inherit system;
    partitionDiskScript = "${pkgs.callPackage ./nixos/scripts/partition/encrypted.nix {
      disk = "/dev/vda";
      swapSize = "1G";
    }}/bin/partition-disks";
    # partitionDiskScript = ''
    #   mkfs.ext4 -b ${toString (4 * 1024)} -F -L nixos /dev/vda
    #   mkdir -p /mnt
    #   mount /dev/disk/by-label/nixos /mnt
    # '';
  };

  # partition-disks && install-nixos
  # TODO use a simple grub legacy partition script from installer or hibernate tests
  # installer-test-helper = pkgs.callPackage ./nixos/lib/vm-install-test.nix {
  #   inherit system;
  #   partitionDiskScript = pkgs.callPackage ./nixos/scripts/partition/encrypted.nix {
  #     disk = "/dev/vda";
  #     swapSize = "1G";
  #   };
  # };

  # partition-disks && install-nixos
  # $ qemu-kvm -m 384 -netdev user,id=net0 -device virtio-net-pci,netdev=net0 $QEMU_OPTS -drive file=./nixos.qcow2,if=virtio,werror=report -cpu max -m 1024
  # <3
  installer-test-helper = pkgs.callPackage ./nixos/lib/vm-install-test.nix {
    inherit system;
    partitionDiskScript = pkgs.callPackage ./nixos/scripts/partition/simple.nix {
      disk = "/dev/vda";
    };
  };

  # BUG: This is producing wrong bios for UEFI...
  bios = ''${pkgs.OVMF.fd}/FV/${if pkgs.stdenv.isAarch64 then "QEMU_EFI.fd" else "OVMF.fd"}'';

  working = (import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
      "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    ];
  })
}
