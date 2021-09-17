{ pkgs
, disk
}:

''
  set -euo pipefail

  flock ${disk} parted --script ${disk} -- \
  mklabel msdos \
  mkpart primary linux-swap 1M 1024M \
  mkpart primary ext2 1024M -1s

  udevadm settle

  mkfs.ext3 -L nixos /dev/vda2
  mount LABEL=nixos /mnt

  mkswap /dev/vda1 -L swap
  swapon /dev/vda1
''
