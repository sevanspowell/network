{ config, pkgs, lib, ... }:

with pkgs;

let
  user = "alice";

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

with (import ./installer.nix { inherit pkgs config; });

# ✓ Start with LUKS simple
# ✓ Add UEFI
# ✓ systemd boot
# ✓ Add ZFS with systemd boot, no LUKS
# ✓ Merge special swap partition (one partition)
# ✓ Setup appropriate zfs partitions
# Make a basic test (touched file in persist stays, otherwise gone on reboot)
# Make ZFS partitions configurable
makeInstallerTest "basic-eyd" {
  createPartitions = ''
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
  bootLoader = "grub";
  grubUseEfi = true;
  extraConfig = ''
    boot.kernelParams = lib.mkAfter [ "console=tty0" ];

    # ZFS
    boot.supportedFilesystems = [ "zfs" ];

    # Using by-uuid overrides the default of by-id, and is unique
    # to the qemu disks, as they don't produce by-id paths for
    # some reason.
    boot.zfs.devNodes = "/dev/disk/by-uuid/";
    networking.hostId = "00000000";

    nix.nixPath =
      [
        "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
        "nixos-config=/persist/etc/nixos/configuration.nix"
        "/nix/var/nix/profiles/per-user/root/channels"
      ];
  '';
  # shutdownCommands = ''
  #     # machine.succeed("umount /mnt/persist || true")
  #     # machine.succeed("umount /mnt/nix || true")
  # '';
  # installCommand = "nixos-install -I 'nixos-config=/mnt/persist/etc/nixos/configuration.nix' < /dev/null >&2";
  # enableOCR = true;
  # preBootCommands = ''
  #   # machine.start()
  #   # machine.wait_for_text("Passphrase for")
  #   # machine.send_chars("supersecret\n")
  # '';
  extraInstallerConfig = {
    boot.supportedFilesystems = [ "zfs" ];
  };
}
