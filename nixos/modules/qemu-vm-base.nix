{ config, lib, pkgs, options, modulesPath, ... }:

with lib;

let
  cfg = config.virtualisation;
in

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  options = {

    # virtualisation.bootDevice =
    #   mkOption {
    #     type = types.str;
    #     example = "/dev/vda";
    #     description =
    #       ''
    #         The disk to be used for the root filesystem.
    #       '';
    #   };

    virtualisation.graphics =
      mkOption {
        default = true;
        description =
          ''
            Whether to run QEMU with a graphics window, or in nographic mode.
            Serial console will be enabled on both settings, but this will
            change the preferred console.
            '';
      };
  };

  config = {

    # boot.loader.grub.device = mkVMOverride (cfg.bootDevice);

    boot.initrd.extraUtilsCommands =
      ''
        # We need mke2fs in the initrd.
        copy_bin_and_libs ${pkgs.e2fsprogs}/bin/mke2fs
      '';

    boot.initrd.postMountCommands =
      ''
        # Mark this as a NixOS machine.
        mkdir -p $targetRoot/etc
        echo -n > $targetRoot/etc/NIXOS

        # Fix the permissions on /tmp.
        chmod 1777 $targetRoot/tmp

        mkdir -p $targetRoot/boot
      '';

    # Don't run ntpd in the guest.  It should get the correct time from KVM.
    services.timesyncd.enable = false;

    # When building a regular system configuration, override whatever
    # video driver the host uses.
    services.xserver.videoDrivers = mkVMOverride [ "modesetting" ];
    services.xserver.defaultDepth = mkVMOverride 0;
    services.xserver.resolutions = mkVMOverride [ { x = 1024; y = 768; } ];
    services.xserver.monitorSection =
      ''
        # Set a higher refresh rate so that resolutions > 800x600 work.
        HorizSync 30-140
        VertRefresh 50-160
      '';

    # Wireless won't work in the VM.
    networking.wireless.enable = mkVMOverride false;
    services.connman.enable = mkVMOverride false;

    # Speed up booting by not waiting for ARP.
    networking.dhcpcd.extraConfig = "noarp";

    networking.usePredictableInterfaceNames = false;

    system.requiredKernelConfig = with config.lib.kernelConfig;
      [ (isEnabled "VIRTIO_BLK")
        (isEnabled "VIRTIO_PCI")
        (isEnabled "VIRTIO_NET")
        (isEnabled "EXT4_FS")
        (isEnabled "NET_9P_VIRTIO")
        (isEnabled "9P_FS")
        (isYes "BLK_DEV")
        (isYes "PCI")
        (isYes "NETDEVICES")
        (isYes "NET_CORE")
        (isYes "INET")
        (isYes "NETWORK_FILESYSTEMS")
      ] ++ optionals (!cfg.graphics) [
        (isYes "SERIAL_8250_CONSOLE")
        (isYes "SERIAL_8250")
      ];

  };
}
