{ pkgs
, disk
, swapSize
, interactive ? false
# ^ Whether to prompt the user for an encryption password, or to use "supersecret"
}:

pkgs.writeShellScriptBin "partition-disks" {} ''
  flock ${disk} parted --script ${disk} -- \
  mklabel gpt \
  mkpart primary 512MiB 100%
  mkpart ESP fat32 1MiB 512MiB
  set 2 esp on

  echo "Formatting boot partition..."
  mkfs.fat -F 32 -n boot ${disk}2

  echo "Setting up LUKS..."
  export LUKS_PV_NAME="nixos-enc"
  export LUKS_PV_PATH="/dev/mapper/''${LUKS_PV_NAME}"
  export LUKS_VG_NAME="nixos-vg"
  export LUKS_VG_PATH="/dev/''${LUKS_VG_NAME}"

  modprobe dm_mod dm_crypt
  ${if interactive
    then ''
      cryptsetup luksFormat "''${DISK_PART_LUKS}"
      cryptsetup luksOpen "''${DISK_PART_LUKS}" "''${LUKS_PV_NAME}"
    ''
    else ''
      echo -n supersecret | cryptsetup luksFormat -q "''${DISK_PART_LUKS}" -,
      echo -n supersecret | cryptsetup luksOpen --key-file - "''${DISK_PART_LUKS}" "''${LUKS_PV_NAME}"
    ''}

  pvcreate "''${LUKS_PV_PATH}"
  vgcreate "''${LUKS_VG_NAME}" "''${LUKS_PV_PATH}"

  info "LUKS: Creating ${swapSize} swap partition ..."
  lvcreate -L "${swapSize}" -n swap "''${LUKS_VG_NAME}"

  export DISK_PART_SWAP="''${LUKS_VG_PATH}/swap"
  mkswap -L swap "''${DISK_PART_SWAP}"
  swapon "''${DISK_PART_SWAP}"

  info "LUKS: Using rest of space for root partion..."
  lvcreate -l 100%FREE -n root "''${LUKS_VG_NAME}"

  export DISK_PART_ROOT="''${LUKS_VG_PATH}/root"

  udevadm settle

  mount LABEL=nixos /mnt
  mount LABEL=BOOT /mnt/boot
'';
