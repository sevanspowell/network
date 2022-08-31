#!/usr/bin/env bash

# Modified from https://gist.githubusercontent.com/mx00s/ea2462a3fe6fdaa65692fe7ee824de3e/raw/ddb4c02a2a0481e9b27aa87ed64c4cdd5398d067/install.sh
#
# NixOS install script synthesized from:
#
#   - Erase Your Darlings (https://grahamc.com/blog/erase-your-darlings)
#   - ZFS Datasets for NixOS (https://grahamc.com/blog/nixos-on-zfs)
#   - NixOS Manual (https://nixos.org/nixos/manual/)
#
# It expects the name of the block device (e.g. 'sda') to partition
# and install NixOS on and an authorized public ssh key to log in as
# 'root' remotely. The script must also be executed as root.
#
# Example: `sudo ./install.sh sde "ssh-rsa AAAAB..."`
#

set -euo pipefail

################################################################################

export COLOR_RESET="\033[0m"
export RED_BG="\033[41m"
export BLUE_BG="\033[44m"

function err {
    echo -e "${RED_BG}$1${COLOR_RESET}"
}

function info {
    echo -e "${BLUE_BG}$1${COLOR_RESET}"
}

################################################################################

export DISK_PATH=$1
export AUTHORIZED_SSH_KEY=$2

if ! [[ -v DISK_PATH ]]; then
    err "Missing argument. Expected block device by id, e.g. '/dev/disk/by-id/nvme-eui.XXX'"
    exit 1
fi

if ! [[ -b "$DISK_PATH" ]]; then
    err "Invalid argument: '${DISK_PATH}' is not a block special file"
    exit 1
fi

if ! [[ -v AUTHORIZED_SSH_KEY ]]; then
    err "Missing argument. Expected public SSH key, e.g. 'ssh-rsa AAAAB...'"
    exit 1
fi

if [[ "$EUID" > 0 ]]; then
    err "Must run as root"
    exit 1
fi

export ZFS_POOL="rpool"

# ephemeral datasets
export ZFS_LOCAL="${ZFS_POOL}/local"
export ZFS_DS_ROOT="${ZFS_LOCAL}/root"
export ZFS_DS_NIX="${ZFS_LOCAL}/nix"
export ZFS_DS_RESERVED="${ZFS_POOL}/reserved"

# persistent datasets
export ZFS_SAFE="${ZFS_POOL}/safe"
export ZFS_DS_HOME="${ZFS_SAFE}/home"
export ZFS_DS_PERSIST="${ZFS_SAFE}/persist"

export ZFS_BLANK_SNAPSHOT="${ZFS_DS_ROOT}@blank"

################################################################################

info "Running the UEFI (GPT) partitioning and formatting directions from the NixOS manual ..."
parted "$DISK_PATH" -- mklabel gpt
parted "$DISK_PATH" -- mkpart primary 512MiB -8GiB
parted "$DISK_PATH" -- mkpart primary linux-swap -8GiB 100%
parted "$DISK_PATH" -- mkpart ESP fat32 1MiB 512MiB
parted "$DISK_PATH" -- set 3 esp on

export DISK_PART_ROOT="${DISK_PATH}-part1"
export DISK_PART_BOOT="${DISK_PATH}-part3"
export DISK_PART_SWAP="${DISK_PATH}-part2"

info "Formatting boot partition ..."
mkfs.fat -F 32 -n boot "$DISK_PART_BOOT"

info "Formatting swap partition ..."
mkswap -L swap "$DISK_PART_SWAP"

info "Creating '$ZFS_POOL' ZFS pool for '$DISK_PART_ROOT' ..."
zpool create -f "$ZFS_POOL" "$DISK_PART_ROOT"

info "Enabling compression for '$ZFS_POOL' ZFS pool ..."
zfs set compression=on "$ZFS_POOL"

# See https://nixos.wiki/wiki/ZFS
info "Creating reserved disk space in case we run out of space and need to delete files ..."
zfs create -o refreservation=1G -o mountpoint=none "$ZFS_DS_RESERVED"

info "Creating '$ZFS_DS_ROOT' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_ROOT"

info "Configuring extended attributes setting for '$ZFS_DS_ROOT' ZFS dataset ..."
zfs set xattr=sa "$ZFS_DS_ROOT"

info "Configuring access control list setting for '$ZFS_DS_ROOT' ZFS dataset ..."
zfs set acltype=posixacl "$ZFS_DS_ROOT"

info "Creating '$ZFS_BLANK_SNAPSHOT' ZFS snapshot ..."
zfs snapshot "$ZFS_BLANK_SNAPSHOT"

info "Mounting '$ZFS_DS_ROOT' to /mnt ..."
mount -t zfs "$ZFS_DS_ROOT" /mnt

info "Mounting '$DISK_PART_BOOT' to /mnt/boot ..."
mkdir /mnt/boot
mount -t vfat /dev/disk/by-label/boot /mnt/boot

info "Turning on swap ..."
swapon /dev/disk/by-label/swap

info "Creating '$ZFS_DS_NIX' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_NIX"

info "Disabling access time setting for '$ZFS_DS_NIX' ZFS dataset ..."
zfs set atime=off "$ZFS_DS_NIX"

info "Mounting '$ZFS_DS_NIX' to /mnt/nix ..."
mkdir /mnt/nix
mount -t zfs "$ZFS_DS_NIX" /mnt/nix

info "Creating '$ZFS_DS_HOME' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_HOME"

info "Mounting '$ZFS_DS_HOME' to /mnt/home ..."
mkdir /mnt/home
mount -t zfs "$ZFS_DS_HOME" /mnt/home

info "Creating '$ZFS_DS_PERSIST' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_PERSIST"

info "Mounting '$ZFS_DS_PERSIST' to /mnt/persist ..."
mkdir /mnt/persist
mount -t zfs "$ZFS_DS_PERSIST" /mnt/persist

info "Permit ZFS auto-snapshots on ${ZFS_SAFE}/* datasets ..."
zfs set com.sun:auto-snapshot=true "$ZFS_DS_HOME"
zfs set com.sun:auto-snapshot=true "$ZFS_DS_PERSIST"

info "Creating persistent directory for host SSH keys ..."
mkdir -p /mnt/persist/etc/ssh

info "Generating NixOS configuration (/mnt/etc/nixos/*.nix) ..."
nixos-generate-config --root /mnt

info "Enter password for the root user ..."
ROOT_PASSWORD_HASH="$(mkpasswd -m sha-512 | sed 's/\$/\\$/g')"

info "Enter personal user name ..."
read USER_NAME

info "Enter password for '${USER_NAME}' user ..."
USER_PASSWORD_HASH="$(mkpasswd -m sha-512 | sed 's/\$/\\$/g')"

info "Moving generated hardware-configuration.nix to /persist/etc/nixos/ ..."
mkdir -p /mnt/persist/etc/nixos
mv /mnt/etc/nixos/hardware-configuration.nix /mnt/persist/etc/nixos/

info "Backing up the originally generated configuration.nix to /persist/etc/nixos/configuration.nix.original ..."
mv /mnt/etc/nixos/configuration.nix /mnt/persist/etc/nixos/configuration.nix.original

info "Backing up the this installer script to /persist/etc/nixos/install.sh.original ..."
cp "$0" /mnt/persist/etc/nixos/install.sh.original

info "Writing NixOS configuration to /persist/etc/nixos/ ..."
cat <<EOF > /mnt/persist/etc/nixos/configuration.nix
{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  nix.nixPath =
    [
      "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
      "nixos-config=/persist/etc/nixos/configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/";

  # source: https://grahamc.com/blog/erase-your-darlings
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r ${ZFS_BLANK_SNAPSHOT}
  '';

  # Set noop scheduler for zfs partitions
  services.udev.extraRules = ''
    ACTION="add|change", KERNEL=="sd[a-z]*[0-9]*|mmcblk[0-9]*p[0-9]*|nvme[0-9]*n[0-9]*p[0-9]*", ENV{ID_FS_TYPE}=="zfs_member", ATTR{../queue/scheduler}="none"
  '';

  networking.hostName = "home-server";
  networking.hostId = "$(head -c 8 /etc/machine-id)";

  networking.useDHCP = false;
  # networking.interfaces.enp3s0.useDHCP = true;

  environment.systemPackages = with pkgs;
    [
      emacs
      vim
      git
    ];

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
    # TODO: autoReplication
  };

  services.openssh = {
    enable = true;
    permitRootLogin = "no";
    passwordAuthentication = false;
    hostKeys =
      [
        {
          path = "/persist/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
        {
          path = "/persist/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
      ];
  };

  users = {
    mutableUsers = false;
    users = {
      root = {
        initialHashedPassword = "${ROOT_PASSWORD_HASH}";
      };

      ${USER_NAME} = {
        createHome = true;
	extraGroups = [ "wheel" ];
	group = "users";
	uid = 1000;
	home = "/home/${USER_NAME}";
	useDefaultShell = true;
        openssh.authorizedKeys.keys = [ "${AUTHORIZED_SSH_KEY}" ];
        isNormalUser = true;
        initialHashedPassword = "${USER_PASSWORD_HASH}";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "L+ /etc/machine-id - - - - /persist/etc/machine-id"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
EOF

info "Installing NixOS to /mnt ..."
ln -s /mnt/persist/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix
ln -s /mnt/persist/etc/machine-id /mnt/etc/machine-id
# info "Install with: nixos-install -I \"nixos-config=/mnt/persist/etc/nixos/configuration.nix\""
nixos-install -I "nixos-config=/mnt/persist/etc/nixos/configuration.nix" --no-root-passwd  # already prompted for and configured password

umount -R /mnt
# Need to export the pool after installing, otherwise NixOS will fail to mount the pool on reboot
zpool export ${ZFS_POOL}
