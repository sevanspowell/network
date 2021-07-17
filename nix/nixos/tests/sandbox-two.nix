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
# Setup appropriate zfs partitions
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
        # "zfs create -p -o mountpoint=legacy ${ZFS_DS_PERSIST}",
        # "mkdir /mnt/persist",
        # "mount -t zfs ${ZFS_DS_PERSIST} /mnt/persist",
        # "zfs set com.sun:auto-snapshot=true ${ZFS_DS_PERSIST}",
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
  '';
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

# makeInstallerTest "zfs-root" {
#   extraInstallerConfig = {
#     boot.supportedFilesystems = [ "zfs" ];

#     system.extraDependencies = with pkgs; [ zfs ];

#     services.zfs = {
#       autoScrub.enable = true;
#       autoSnapshot.enable = true;
#       # TODO: autoReplication
#     };
#   };

#   extraConfig = ''
#     boot.supportedFilesystems = [ "zfs" ];

#     # Using by-uuid overrides the default of by-id, and is unique
#     # to the qemu disks, as they don't produce by-id paths for
#     # some reason.
#     boot.zfs.devNodes = "/dev/disk/by-uuid/";
#     networking.hostId = "00000000";

#     # nix.nixPath =
#     #   [
#     #     "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
#     #     "nixos-config=/persist/etc/nixos/configuration.nix"
#     #     "/nix/var/nix/profiles/per-user/root/channels"
#     #   ];

#     services.zfs = {
#       autoScrub.enable = true;
#       autoSnapshot.enable = true;
#       # TODO: autoReplication
#     };

#     # boot.loader.systemd-boot.enable = true;
#     boot.loader.efi.canTouchEfiVariables = true;

#     # source: https://grahamc.com/blog/erase-your-darlings
#     # boot.initrd.postDeviceCommands = lib.mkAfter '''
#     #   zfs rollback -r ${ZFS_BLANK_ROOT_SNAPSHOT}
#     #   zfs rollback -r ${ZFS_BLANK_HOME_SNAPSHOT}
#     # ''';
#     boot.initrd.luks.devices = {
#       root = {
#         device = "${DISK_PART_LUKS}";
#         preLVM = true;
#       };
#     };
#     swapDevices = [
#       { device = "${DISK_PART_SWAP}"; }
#     ];

#     # source: https://grahamc.com/blog/nixos-on-zfs
#     boot.kernelParams = lib.mkAfter [ "console=tty0" "elevator=none" ];
#   '';

#   # createPartitions = ''
#   #   machine.succeed(
#   #       "flock ${DISK_PATH} parted --script ${DISK_PATH} -- mklabel gpt"
#   #       + " mkpart primary 512MiB 100%"
#   #       + " mkpart ESP fat32 1MiB 512MiB"
#   #       + " set 2 esp on",
#   #       "udevadm settle",
#   #       "mkfs.fat -F 32 -n boot ${DISK_PART_BOOT}",
#   #       "echo -n supersecret | cryptsetup luksFormat -q ${DISK_PART_LUKS} -",
#   #       "echo -n supersecret | cryptsetup luksOpen ${DISK_PART_LUKS} ${VOL_PV_NAME}",
#   #       "pvcreate ${VOL_PV_PATH}",
#   #       "vgcreate ${VOL_VG_NAME} ${VOL_PV_PATH}",
#   #       "lvcreate -L ${SWAP_AMT} -n swap ${VOL_VG_NAME}",
#   #       "mkswap -L swap ${DISK_PART_SWAP}",
#   #       "swapon ${DISK_PART_SWAP}",
#   #       "lvcreate -l 100%FREE -n root ${VOL_VG_NAME}",
#   #       "zpool create -f ${ZFS_POOL} ${DISK_PART_ROOT}",
#   #       "zfs set compression=on ${ZFS_POOL}",
#   #       # Root
#   #       "zfs create -p -o mountpoint=legacy ${ZFS_DS_ROOT}",
#   #       "zfs set xattr=sa ${ZFS_DS_ROOT}",
#   #       "zfs set acltype=posixacl ${ZFS_DS_ROOT}",
#   #       "zfs snapshot ${ZFS_BLANK_ROOT_SNAPSHOT}",
#   #       "mount -t zfs ${ZFS_DS_ROOT} /mnt",
#   #       # Boot
#   #       "mkdir /mnt/boot",
#   #       "mount -t vfat ${DISK_PART_BOOT} /mnt/boot",
#   #       # Nix
#   #       "zfs create -p -o mountpoint=legacy ${ZFS_DS_NIX}",
#   #       "zfs set atime=off ${ZFS_DS_NIX}",
#   #       "mkdir /mnt/nix",
#   #       "mount -t zfs ${ZFS_DS_NIX} /mnt/nix",
#   #       # Home
#   #       "zfs create -p -o mountpoint=legacy ${ZFS_DS_HOME}",
#   #       "zfs snapshot ${ZFS_BLANK_HOME_SNAPSHOT}",
#   #       "mkdir /mnt/home",
#   #       "mount -t zfs ${ZFS_DS_HOME} /mnt/home",
#   #       # Persist
#   #       "zfs create -p -o mountpoint=legacy ${ZFS_DS_PERSIST}",
#   #       "mkdir /mnt/persist",
#   #       "mount -t zfs ${ZFS_DS_PERSIST} /mnt/persist",
#   #       "zfs set com.sun:auto-snapshot=true ${ZFS_DS_HOME}",
#   #       "zfs set com.sun:auto-snapshot=true ${ZFS_DS_PERSIST}",
#   #       "mkdir -p /mnt/persist/etc/ssh",
#   #   )
#   # '';

#   createPartitions = ''
#     machine.succeed(
#         "flock /dev/vda parted --script /dev/vda -- mklabel gpt"
#         + " mkpart primary ext2 1M 50MB"  # /boot
#         + " mkpart primary linux-swap 50M 1024M"
#         + " mkpart primary 1024M -1s",  # LUKS
#         "udevadm settle",
#         "mkswap /dev/vda2 -L swap",
#         "swapon -L swap",
#         "modprobe dm_mod dm_crypt",
#         "echo -n supersecret | cryptsetup luksFormat -q /dev/vda3 -",
#         "echo -n supersecret | cryptsetup luksOpen --key-file - /dev/vda3 cryptroot",
#         "mkfs.ext3 -L nixos /dev/mapper/cryptroot",
#         "mount LABEL=nixos /mnt",
#         "mkfs.ext3 -L boot /dev/vda1",
#         "mkdir -p /mnt/boot",
#         "mount LABEL=boot /mnt/boot",
#     )
#   '';

#   # bootLoader = "systemd-boot";

#   preBootCommands = ''
#     machine.start()
#     machine.wait_for_text("Passphrase for")
#     machine.send_chars("supersecret\n")
#   '';
# }

# makeInstallerTest "basic-eyd" {
#   createPartitions = ''
#     machine.succeed(
#         "flock ${DISK_PATH} parted --script ${DISK_PATH} -- mklabel gpt"
#         + " mkpart primary 512MiB 100%"
#         + " mkpart ESP fat32 1MiB 512MiB"
#         + " set 2 esp on",
#         "mkfs.fat -F 32 -n boot ${DISK_PART_BOOT}",
#         "echo -n supersecret | cryptsetup luksFormat -q ${DISK_PART_LUKS} -",
#         "echo -n supersecret | cryptsetup luksOpen ${DISK_PART_LUKS} ${VOL_PV_NAME}",
#         "pvcreate ${VOL_PV_PATH}",
#         "vgcreate ${VOL_VG_NAME} ${VOL_PV_PATH}",
#         "lvcreate -L ${SWAP_AMT} -n swap ${VOL_VG_NAME}",
#         "mkswap -L swap ${DISK_PART_SWAP}",
#         "swapon ${DISK_PART_SWAP}",
#         "lvcreate -l 100%FREE -n root ${VOL_VG_NAME}",
#         "zpool create -f ${ZFS_POOL} ${DISK_PART_ROOT}",
#         "zfs set compression=on ${ZFS_POOL}",
#         # Root
#         "zfs create -p -o mountpoint=legacy ${ZFS_DS_ROOT}",
#         "zfs set xattr=sa ${ZFS_DS_ROOT}",
#         "zfs set acltype=posixacl ${ZFS_DS_ROOT}",
#         "zfs snapshot ${ZFS_BLANK_ROOT_SNAPSHOT}",
#         "mount -t zfs ${ZFS_DS_ROOT} /mnt",
#         # Boot
#         "mkdir /mnt/boot",
#         "mount -t vfat ${DISK_PART_BOOT} /mnt/boot",
#         # Nix
#         "zfs create -p -o mountpoint=legacy ${ZFS_DS_NIX}",
#         "zfs set atime=off ${ZFS_DS_NIX}",
#         "mkdir /mnt/nix",
#         "mount -t zfs ${ZFS_DS_NIX} /mnt/nix",
#         # Home
#         "zfs create -p -o mountpoint=legacy ${ZFS_DS_HOME}",
#         "zfs snapshot ${ZFS_BLANK_HOME_SNAPSHOT}",
#         "mkdir /mnt/home",
#         "mount -t zfs ${ZFS_DS_HOME} /mnt/home",
#         # Persist
#         "zfs create -p -o mountpoint=legacy ${ZFS_DS_PERSIST}",
#         "mkdir /mnt/persist",
#         "mount -t zfs ${ZFS_DS_PERSIST} /mnt/persist",
#         "zfs set com.sun:auto-snapshot=true ${ZFS_DS_HOME}",
#         "zfs set com.sun:auto-snapshot=true ${ZFS_DS_PERSIST}",
#         "mkdir -p /mnt/persist/etc/ssh",
#     )
#   '';

#   extraInstallerConfig = {
#     boot.supportedFilesystems = [ "zfs" ];
#   };

#   extraConfig = ''
#     nix.nixPath =
#       [
#         "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
#         "nixos-config=/persist/etc/nixos/configuration.nix"
#         "/nix/var/nix/profiles/per-user/root/channels"
#       ];

#     services.zfs = {
#       autoScrub.enable = true;
#       autoSnapshot.enable = true;
#       # TODO: autoReplication
#     };

#     boot.supportedFilesystems = [ "zfs" ];

#     # Using by-uuid overrides the default of by-id, and is unique
#     # to the qemu disks, as they don't produce by-id paths for
#     # some reason.
#     boot.zfs.devNodes = "/dev/disk/by-uuid/";

#     # ZFS requires this to be set
#     networking.hostId = "00000000";

#     boot.loader.systemd-boot.enable = true;
#     boot.loader.efi.canTouchEfiVariables = true;

#     # source: https://grahamc.com/blog/erase-your-darlings
#     boot.initrd.postDeviceCommands = lib.mkAfter '''
#       zfs rollback -r ${ZFS_BLANK_ROOT_SNAPSHOT}
#       zfs rollback -r ${ZFS_BLANK_HOME_SNAPSHOT}
#     ''';
#     boot.initrd.luks.devices = {
#       root = {
#         device = "${DISK_PART_LUKS}";
#         preLVM = true;
#       };
#     };
#     swapDevices = [
#       { device = "${DISK_PART_SWAP}"; }
#     ];

#     # source: https://grahamc.com/blog/nixos-on-zfs
#     boot.kernelParams = [ "elevator=none" ];
#   '';

#   preBootCommands = ''
#     machine.start()
#     machine.wait_for_text("Passphrase for")
#     machine.send_chars("supersecret\n")
#   '';
# }

# Create two physical LVM partitions combined into one volume group
# that contains the logical swap and root partitions.
# makeInstallerTest "lvm" {
#   createPartitions = ''
#     machine.succeed(
#         "flock /dev/vda parted --script /dev/vda -- mklabel msdos"
#         + " mkpart primary 1M 2048M"  # PV1
#         + " set 1 lvm on"
#         + " mkpart primary 2048M -1s"  # PV2
#         + " set 2 lvm on",
#         "udevadm settle",
#         "pvcreate /dev/vda1 /dev/vda2",
#         "vgcreate MyVolGroup /dev/vda1 /dev/vda2",
#         "lvcreate --size 1G --name swap MyVolGroup",
#         "lvcreate --size 2G --name nixos MyVolGroup",
#         "mkswap -f /dev/MyVolGroup/swap -L swap",
#         "swapon -L swap",
#         "mkfs.xfs -L nixos /dev/MyVolGroup/nixos",
#         "mount LABEL=nixos /mnt",
#     )
#   '';
# }
