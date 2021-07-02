{ config, pkgs, lib, ... }:

with pkgs;

let
  user = "alice"; 
in

{
  name = "sandbox-environment";

  nodes = {
    machine0 = { config, ... }:
      let
        vm = pkgs.vmTools.runInLinuxVM (
            pkgs.runCommand "nixos-boot-disk"
              { preVM =
                  ''
                    mkdir $out
                    diskImage=$out/disk.img
                    bootFlash=$out/bios.bin
                    ${qemu}/bin/qemu-img create -f qcow2 $diskImage "40M"
                    ${if true then ''
                      cp ${pkgs.OVMF-CSM.fd}/FV/OVMF.fd $bootFlash
                      chmod 0644 $bootFlash
                    '' else ''
                    ''}
                  '';
                buildInputs = [ pkgs.utillinux ];
                QEMU_OPTS = if true
                            then "-pflash $out/bios.bin -nographic -serial pty"
                            else "-nographic -serial pty";
              }
              ''
                # Create a /boot EFI partition with 40M and arbitrary but fixed GUIDs for reproducibility
                ${pkgs.gptfdisk}/bin/sgdisk \
                  --set-alignment=1 --new=1:34:2047 --change-name=1:BIOSBootPartition --typecode=1:ef02 \
                  --set-alignment=512 --largest-new=2 --change-name=2:EFISystem --typecode=2:ef00 \
                  --attributes=1:set:1 \
                    --attributes=2:set:2 \
                  --disk-guid=97FD5997-D90B-4AA3-8D16-C1723AEA73C1 \
                  --partition-guid=1:1C06F03B-704E-4657-B9CD-681A087A2FDC \
                  --partition-guid=2:970C694F-AFD0-4B99-B750-CDB7A329AB6F \
                  --hybrid 2 \
                  --recompute-chs /dev/vda
                ${pkgs.dosfstools}/bin/mkfs.fat -F16 /dev/vda2
                export MTOOLS_SKIP_CHECK=1
                ${pkgs.mtools}/bin/mlabel -i /dev/vda2 ::boot
      
                # Mount /boot; load necessary modules first.
                ${pkgs.kmod}/bin/insmod ${pkgs.linux}/lib/modules/*/kernel/fs/nls/nls_cp437.ko.xz || true
                ${pkgs.kmod}/bin/insmod ${pkgs.linux}/lib/modules/*/kernel/fs/nls/nls_iso8859-1.ko.xz || true
                ${pkgs.kmod}/bin/insmod ${pkgs.linux}/lib/modules/*/kernel/fs/fat/fat.ko.xz || true
                ${pkgs.kmod}/bin/insmod ${pkgs.linux}/lib/modules/*/kernel/fs/fat/vfat.ko.xz || true
                ${pkgs.kmod}/bin/insmod ${pkgs.linux}/lib/modules/*/kernel/fs/efivarfs/efivarfs.ko.xz || true
                mkdir /boot
                mount /dev/vda2 /boot
      
                # This is needed for GRUB 0.97, which doesn't know about virtio devices.
                mkdir /boot/grub
                echo '(hd0) /dev/vda' > /boot/grub/device.map
      
                # Install GRUB and generate the GRUB boot menu.
                touch /etc/NIXOS
                mkdir -p /nix/var/nix/profiles
                ${config.system.build.toplevel}/bin/switch-to-configuration boot
      
                umount /boot
              '' # */
          );
      
      y = pkgs.runCommand "y" {} ''
          mkdir $out
          ${qemu}/bin/qemu-img create -f qcow2 $out/disk.img \
            ${toString config.virtualisation.diskSize}M || exit 1
          ls -lah .
          ls -lah $out
        '';
      in
        
    {
      nixpkgs.pkgs = pkgs;
      imports = [
        "${sources.home-manager}/nixos"
      ];


      home-manager.users."${user}" = {...}: {
        imports = [
          ../../../modules/home/emacs/persist.nix
        ];
      };

      # virtualisation.qemu.drives = lib.mkForce [
      #   {
      #     file = "$TMPDIR/disk.img";
      #     driveExtraOpts.media = "disk";
      #     deviceExtraOpts.bootindex = "1";
      #   }
      # ];

      # virtualisation.diskImage = "/etc/test.img";

      # environment.etc."test.img" =
      #   let
      #     img = pkgs.runCommand "mk-vm" {} ''
      #         mkdir $out
      #         ${pkgs.qemu}/bin/qemu-img create -f qcow2 $out/test.img \
      #           400M
      #       '';
      #   in
      #     { source = "${img}/test.img";
      #       mode = "0666";
      #     };

      users = {
        mutableUsers = false;

        users = {
          # For ease of debugging the VM as the `root` user
          root.password = "";

          "${user}" = {
            isNormalUser = true;
            createHome = true;
            home = "/home/${user}";
          };
        };
      };

      systemd.tmpfiles.rules = [
        "d /home/${user} - ${user} users - -"
        "L /home/${user}/.nix-profile - - - - /nix/var/nix/profiles/per-user/${user}/profile"
        "d /home/${user}/.nix-defexpr - ${user} users - -"
        "L /home/${user}/.nix-defexpr/channels - - - - /nix/var/nix/profiles/per-user/${user}/channels"
      ];

    };
  };

  testScript =
    ''
    import json
    import sys

    start_all()
    '';
}
