{
  makeTest = name:
    { nodes ? {} }:
    {
      inherit enableOCR;
      name = name;
      nodes = {

        # The configuration of the machine used to run "nixos-install".
        machine = { pkgs, ... }: {
          imports = [
            (pkgsPath + "/nixos/modules/profiles/installation-device.nix")
            (pkgsPath + "/nixos/modules/profiles/base.nix")
            extraInstallerConfig
          ];

          virtualisation.diskSize = 8 * 1024;
          virtualisation.memorySize = 1536;

          # Use a small /dev/vdb as the root disk for the
          # installer. This ensures the target disk (/dev/vda) is
          # the same during and after installation.
          virtualisation.emptyDiskImages = [ 512 ];
          virtualisation.bootDevice =
            if grubVersion == 1 then "/dev/sdb" else "/dev/vdb";
          virtualisation.qemu.diskInterface =
            if grubVersion == 1 then "scsi" else "virtio";

          boot.loader.systemd-boot.enable = mkIf (bootLoader == "systemd-boot") true;

          hardware.enableAllFirmware = mkForce false;

          # The test cannot access the network, so any packages we
          # need must be included in the VM.
          system.extraDependencies = with pkgs; [
            desktop-file-utils
            docbook5
            docbook_xsl_ns
            libxml2.bin
            libxslt.bin
            nixos-artwork.wallpapers.simple-dark-gray-bottom
            ntp
            perlPackages.ListCompare
            perlPackages.XMLLibXML
            shared-mime-info
            sudo
            texinfo
            unionfs-fuse
            xorg.lndir

            # add curl so that rather than seeing the test attempt to download
            # curl's tarball, we see what it's trying to download
            curl
          ]
          ++ optional (bootLoader == "grub" && grubVersion == 1) pkgs.grub
          ++ optionals (bootLoader == "grub" && grubVersion == 2) [
            pkgs.grub2
            pkgs.grub2_efi
          ];

          nix.binaryCaches = mkForce [ ];
          nix.extraOptions = ''
            hashed-mirrors =
            connect-timeout = 1
          '';
        };

      };

      testScript = testScriptFun {
        inherit bootLoader createPartitions preBootCommands postBootCommands
                grubVersion grubDevice grubIdentifier grubUseEfi extraConfig
                testSpecialisationConfig;
      };
    };
}
