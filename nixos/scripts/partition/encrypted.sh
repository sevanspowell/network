
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
