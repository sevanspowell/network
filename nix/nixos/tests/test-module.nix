{ config, pkgs, lib, ... }:

let
  eyd = import ./lib/eyd.nix { inherit lib; };

  sources = import ../../sources.nix;

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

in
  eyd.mkTest {
    nodes = {
      machine = { pkgs, ... }: {
        imports = [
          "${sources.home-manager}/nixos"
          ../../../modules/yubikey-gpg/default.nix
          ../../../modules/yubikey-gpg/persist.nix
        ];

        users = {
          mutableUsers = false;

          users = {
            # For ease of debugging the VM as the `root` user
            root.password = "";

            alice = {
              isNormalUser = true;
              createHome = true;
              home = "/home/alice";
            };
          };
        };
      };
    };

    testScript = ''
      machine.start()
      machine.succeed("touch /home/alice/file.txt")
      machine.shutdown()

      machine.start()
      machine.wait_for_unit("network.target")
      machine.fail("test -e /home/alice/file.txt")
      machine.shutdown()
    '';

    installerConfig = {
      machine = {
        extraInstallerConfig = {
          boot.supportedFilesystems = [ "zfs" ];
        };
        bootLoader = "grub";
        grubVersion = 2;

        createPartitions = "";
        preBootCommands = "";
        postBootCommands = "";
        grubDevice = "/dev/vda";
        grubIdentifier = "uuid";
        grubUseEfi = true;
        enableOCR = false;
      };
    };

    createPartitions = {
      machine = ''
        machine.succeed(
            "flock ${DISK_PATH} parted --script ${DISK_PATH} -- mklabel gpt"
            + " mkpart ESP fat32 1M 50MiB"  # /boot
            + " set 1 boot on"
            + " mkpart primary 50MiB -1MiB",  # /
            "udevadm settle",
            "pvcreate ${DISK_PART_VOL}",
            "vgcreate ${VOL_VG_NAME} ${DISK_PART_VOL}",
            #
            # SWAP
            #
            "lvcreate -L 1G -n swap ${VOL_VG_NAME}",
            "mkswap -L swap ${DISK_PART_SWAP}",
            "swapon -L swap",
            #
            # ROOT
            #
            "lvcreate -l 100%FREE -n root ${VOL_VG_NAME}",
            "zpool create -f ${ZFS_POOL} ${DISK_PART_ROOT}",
            "zfs set compression=on ${ZFS_POOL}",
            "zfs create -p -o mountpoint=legacy ${ZFS_DS_ROOT}",
            "zfs set xattr=sa ${ZFS_DS_ROOT}",
            "zfs set acltype=posixacl ${ZFS_DS_ROOT}",
            "zfs snapshot ${ZFS_BLANK_ROOT_SNAPSHOT}",
            "mount -t zfs ${ZFS_DS_ROOT} /mnt",
            "zfs create -p -o mountpoint=legacy ${ZFS_DS_NIX}",
            "zfs set atime=off ${ZFS_DS_NIX}",
            "mkdir /mnt/nix",
            "mount -t zfs ${ZFS_DS_NIX} /mnt/nix",
            "zfs create -p -o mountpoint=legacy ${ZFS_DS_PERSIST}",
            "mkdir /mnt/persist",
            "mount -t zfs ${ZFS_DS_PERSIST} /mnt/persist",
            "zfs set com.sun:auto-snapshot=true ${ZFS_DS_PERSIST}",
            # "udevadm settle",
            #
            # BOOT
            #
            "mkfs.vfat -n BOOT ${DISK_PART_BOOT}",
            "mkdir -p /mnt/boot",
            "mount LABEL=BOOT /mnt/boot",
            "udevadm settle",
        )
      '';
    };
  }
