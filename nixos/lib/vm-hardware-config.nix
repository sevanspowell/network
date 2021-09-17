# 1. Create a base disk image using the installer profile.
# 2. Add an additional disk to partition
# 3. Partition disks on additional disk
# 4. Generate hardware-configuration.nix on additional disk
# 5. Copy out hardware-configuration.nix
#
# For this to be useful, you must partition your disk with labels, so that the
# generated hardware-configuration.nix can be used across machines.
{ pkgs
, system
, partitionDiskScript
# ^ Script to partition disks on /dev/vda
, diskSize ? (8 * 1024)
# ^ Size of initial disk (M)
, rootMount ? "/mnt"
# ^ Where the root partition is mounted after running partitionDiskScript
}:

let
  nixpkgs = pkgs.lib.cleanSource pkgs.path;

  # Configuration for "installer" machine
  machineConfiguration = import ../modules/installer-vm {
    inherit diskSize;
  };

  config = import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      machineConfiguration
    ];
  };

  binPath = with pkgs; lib.makeBinPath (
    [ rsync
      util-linux
      dosfstools
      parted
      kmod
      lvm2
      e2fsprogs
      cryptsetup
      lkl
      config.config.system.build.nixos-install
      config.config.system.build.nixos-enter
      config.config.system.build.nixos-generate-config
      systemd
      nix
    ] ++ stdenv.initialPath);

  partitionDiskScriptBin = pkgs.writeShellScriptBin "partition-disks" partitionDiskScript;
in

with import "${nixpkgs}/nixos/lib/testing-python.nix" { inherit system pkgs; };

runInMachine {
  drv = pkgs.runCommand "gen-hardware-config" { } ''
    export PATH=${binPath}

    ${partitionDiskScriptBin}/bin/partition-disks
    # Force nixos-generate-config to use labels so we're portable across vms
    rm -rf /dev/disk/by-uuid/*

    nixos-generate-config --root ${rootMount}
    cp ${rootMount}/etc/nixos/hardware-configuration.nix $out/
  '';

  machine = machineConfiguration;
}
