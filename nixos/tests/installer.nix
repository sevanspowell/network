{ config, pkgs, system, lib, ... }:
let
  nixpkgs = pkgs.lib.cleanSource pkgs.path;

  installedConfig = with pkgs.lib; { modulesPath, ...}: {
    imports = [
      "${modulesPath}/testing/test-instrumentation.nix"
      "${modulesPath}/profiles/qemu-guest.nix"
      "${modulesPath}/profiles/minimal.nix"
    ];

    hardware.enableAllFirmware = mkForce false;
    documentation.nixos.enable = false;
    boot.loader.grub.device = "/dev/vda";

    fileSystems = {
      "/".device = "/dev/vda2";
    };
    swapDevices = mkOverride 0 [ { device = "/dev/vda1"; } ];
  };

  installedSystem = (import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [ installedConfig ];
  }).config.system.build.toplevel;

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

      # builds stuff in the VM, needs more juice
      virtualisation.cores = 8;
      virtualisation.memorySize = 1536;
      virtualisation.diskSize = 8 * 1024;

      virtualisation.emptyDiskImages = [
        # Small root disk for installer
        512
      ];
      virtualisation.bootDevice = "/dev/vdb";

      nix.binaryCaches = pkgs.lib.mkForce [ ];
      nix.extraOptions = ''
        hashed-mirrors =
        connect-timeout = 1
      '';
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

      machine.start()
      with subtest("Assert that /boot get mounted"):
          machine.wait_for_unit("local-fs.target")
          ${if true
              then ''machine.succeed("test -e /boot/grub")''
              else ''machine.succeed("test -e /boot/loader/loader.conf")''
          }

      with subtest("Check whether /root has correct permissions"):
          assert "700" in machine.succeed("stat -c '%a' /root")

      with subtest("Assert swap device got activated"):
          # uncomment once https://bugs.freedesktop.org/show_bug.cgi?id=86930 is resolved
          machine.wait_for_unit("swap.target")
          machine.succeed("cat /proc/swaps | grep -q /dev")

      with subtest("Check that the store is in good shape"):
          machine.succeed("nix-store --verify --check-contents >&2")

      with subtest("Check whether the channel works"):
          machine.succeed("nix-env -iA nixos.procps >&2")
          assert ".nix-profile" in machine.succeed("type -tP ps | tee /dev/stderr")
    '';
}
