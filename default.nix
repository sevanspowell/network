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
    partitionDiskScript = ''
      mkfs.ext4 -b ${toString (4 * 1024)} -F -L nixos /dev/vda
      mkdir -p /mnt
      mount /dev/disk/by-label/nixos /mnt
    '';
  };
}
