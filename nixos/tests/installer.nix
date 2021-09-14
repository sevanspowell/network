{ config, pkgs, system, lib, ... }:
let
  nixpkgs = pkgs.lib.cleanSource pkgs.path;
in
{
  name = "installer";

  nodes = {
    machine = { config, ... }:
    {
      imports = [
        "${nixpkgs}/nixos/modules/profiles/installation-device.nix"
        "${nixpkgs}/nixos/modules/profiles/base.nix"
      ];

      # virtualisation.qemu.options = [];
      virtualisation.diskSize = 8 * 1024;
      virtualisation.emptyDiskImages = [
        # Small root disk for installer
        512
      ];
      virtualisation.bootDevice = "/dev/vdb";
    };
  };

  testScript =
    ''
      machine.start()
      machine.succeed(
          "flock /dev/vda parted --script /dev/vda -- mklabel msdos"
          + " mkpart primary linux-swap 1M 1024M"
          + " mkpart primary ext2 1024M -1s",
          "udevadm settle",
          "mkfs.ext3 -L nixos /dev/vda2",
          "mount LABEL=nixos /mnt",
          "mkswap /dev/vda1 -L swap",
          # Install onto /mnt
          "nix-store --load-db < ${pkgs.closureInfo {rootPaths = [installedSystem];}}/registration",
          "nixos-install --root /mnt --system ${installedSystem} --no-root-passwd",
      )
      machine.shutdown()
    '';
}
