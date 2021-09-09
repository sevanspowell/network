{ pkgs
, system
, lib
, supportedSystems ? [ "x86_64-linux" ]
}:

with pkgs;

 let
  forAllSystems = pkgs.lib.genAttrs supportedSystems;

  importTest = fn: args: system: let
    imported = import fn;
    test = import (pkgs.path + "/nixos/tests/make-test-python.nix") imported;
  in test ({
    inherit pkgs system config;
  } // args);

  callTest = fn: args: forAllSystems (system: let test = importTest fn args system; in { inherit test; });

  DISK_PATH = "/dev/vda";
  DISK_PART_BOOT = "${DISK_PATH}1";
  DISK_PART_VOL = "${DISK_PATH}2";
  VOL_PV_NAME = "nixos-enc";
  VOL_PV_PATH = "/dev/mapper/${VOL_PV_NAME}";
  VOL_VG_NAME = "nixos-vg";
  VOL_VG_PATH = "/dev/${VOL_VG_NAME}";
  DISK_PART_SWAP = "${VOL_VG_PATH}/swap";
  DISK_PART_ROOT= "${VOL_VG_PATH}/root";
  SWAP_AMT = "1G";

  ZFS_POOL = "rpool";
  # ephemeral datasets
  ZFS_LOCAL = "${ZFS_POOL}/local";
  ZFS_DS_ROOT = "${ZFS_LOCAL}/root";
  ZFS_DS_NIX = "${ZFS_LOCAL}/nix";
  # persistent datasets
  ZFS_SAFE = "${ZFS_POOL}/safe";
  ZFS_DS_HOME = "${ZFS_SAFE}/home";
  ZFS_DS_PERSIST = "${ZFS_SAFE}/persist";

  ZFS_BLANK_ROOT_SNAPSHOT = "${ZFS_DS_ROOT}@blank";
  ZFS_BLANK_HOME_SNAPSHOT = "${ZFS_DS_HOME}@blank";
in rec {
  sandbox = callTest ./sandbox.nix {};
  sandbox-two = callTest ./sandbox-two.nix {};
  test-module = callTest ./test-module.nix {};

  eyd-image = import ./lib/mk-eyd-image-2.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    inherit system;
    partitionDiskScript = ''
      parted --script ${DISK_PATH} -- \
        mklabel gpt \
        mkpart ESP fat32 1M 50MiB \
        set 1 boot on \
        mkpart primary 50MiB -1MiB

      udevadm settle
      pvcreate ${DISK_PART_VOL}
      vgcreate ${VOL_VG_NAME} ${DISK_PART_VOL}

      #
      # SWAP
      #
      lvcreate -L 500M -n swap ${VOL_VG_NAME} --verbose
      mkswap -L swap ${DISK_PART_SWAP}
      swapon -L swap

      #
      # ROOT
      #
      lvcreate -l 100%FREE -n root ${VOL_VG_NAME}
      zpool create -f ${ZFS_POOL} ${DISK_PART_ROOT}
      zfs set compression=on ${ZFS_POOL}
      zfs create -p -o mountpoint=legacy ${ZFS_DS_ROOT}
      zfs set xattr=sa ${ZFS_DS_ROOT}
      zfs set acltype=posixacl ${ZFS_DS_ROOT}
      zfs snapshot ${ZFS_BLANK_ROOT_SNAPSHOT}
      mount -t zfs ${ZFS_DS_ROOT} /mnt
      zfs create -p -o mountpoint=legacy ${ZFS_DS_NIX}
      zfs set atime=off ${ZFS_DS_NIX}
      mkdir /mnt/nix
      mount -t zfs ${ZFS_DS_NIX} /mnt/nix
      zfs create -p -o mountpoint=legacy ${ZFS_DS_PERSIST}
      mkdir /mnt/persist
      mount -t zfs ${ZFS_DS_PERSIST} /mnt/persist
      zfs set com.sun:auto-snapshot=true ${ZFS_DS_PERSIST}
      #
      # BOOT
      #
      mkfs.vfat -n BOOT ${DISK_PART_BOOT}
      mkdir -p /mnt/boot
      mount LABEL=BOOT /mnt/boot
      udevadm settle
    '';
  };

  hardwareConf = (import ./lib/eyd.nix { inherit pkgs system lib; }).hardwareConfiguration "";
  hardwareConf2 = (import ./lib/eyd.nix {
    inherit pkgs system lib;
  }).hardwareConfiguration2
    {
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
          autoResize = true;
        };

        boot.growPartition = true;
        boot.kernelParams = [ "console=ttyS0" ];
        boot.loader.grub.device = "/dev/vda";
        boot.loader.timeout = 0;

        boot.initrd.kernelModules = [
          "dm-snapshot" # when you are using snapshots
          "dm-raid" # e.g. when you are configuring raid1 via: `lvconvert -m1 /dev/pool/home`
        ];

        imports = [
          "${pkgs.path}/nixos/modules/installer/tools/tools.nix"
          "${pkgs.path}/nixos/modules/profiles/base.nix"
          "${pkgs.path}/nixos/modules/profiles/installation-device.nix"
        ];
    }
  ''
    parted --script ${DISK_PATH} -- \
      mklabel gpt \
      mkpart ESP fat32 1M 50MiB \
      set 1 boot on \
      mkpart primary 50MiB -1MiB

    udevadm settle
    pvcreate ${DISK_PART_VOL}
    vgcreate ${VOL_VG_NAME} ${DISK_PART_VOL}

    #
    # SWAP
    #
    lvcreate -L 500M -n swap ${VOL_VG_NAME} --verbose
    mkswap -L swap ${DISK_PART_SWAP}
    swapon -L swap

    #
    # ROOT
    #
    lvcreate -l 100%FREE -n root ${VOL_VG_NAME}
    zpool create -f ${ZFS_POOL} ${DISK_PART_ROOT}
    zfs set compression=on ${ZFS_POOL}
    zfs create -p -o mountpoint=legacy ${ZFS_DS_ROOT}
    zfs set xattr=sa ${ZFS_DS_ROOT}
    zfs set acltype=posixacl ${ZFS_DS_ROOT}
    zfs snapshot ${ZFS_BLANK_ROOT_SNAPSHOT}
    mount -t zfs ${ZFS_DS_ROOT} /mnt
    zfs create -p -o mountpoint=legacy ${ZFS_DS_NIX}
    zfs set atime=off ${ZFS_DS_NIX}
    mkdir /mnt/nix
    mount -t zfs ${ZFS_DS_NIX} /mnt/nix
    zfs create -p -o mountpoint=legacy ${ZFS_DS_PERSIST}
    mkdir /mnt/persist
    mount -t zfs ${ZFS_DS_PERSIST} /mnt/persist
    zfs set com.sun:auto-snapshot=true ${ZFS_DS_PERSIST}
    #
    # BOOT
    #
    mkfs.vfat -n BOOT ${DISK_PART_BOOT}
    mkdir -p /mnt/boot
    mount LABEL=BOOT /mnt/boot
    udevadm settle
  '';
}
