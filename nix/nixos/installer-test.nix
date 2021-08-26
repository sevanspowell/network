# Configuration of a machine running some sort of install test
{ config, pkgs, lib, modulesPath, ... }:

with lib;

let
  cfg = config.installer-test;
in
rec {
  options.installer-test = {
    bootLoader = mkOption {
      type = types.enum [ "grub" "systemd-boot" ];
      default = "grub";
      description = ''
        Which boot loader to use.
      '';
    };

    grubVersion = mkOption {
      type = types.int;
      default = 2;
      description = ''
        The version of grub to use.
      '';
    };
  };

  imports = [
    "${modulesPath}/profiles/installation-device.nix"
    "${modulesPath}/profiles/base.nix"
  ];

  config = { 
    virtualisation.diskSize = 8 * 1024;
    virtualisation.memorySize = 1536;
  
    # Use a small /dev/vdb as the root disk for the
    # installer. This ensures the target disk (/dev/vda) is
    # the same during and after installation.
    virtualisation.emptyDiskImages = [ 512 ];
    virtualisation.bootDevice =
      if cfg.grubVersion == 1 then "/dev/sdb" else "/dev/vdb";
    virtualisation.qemu.diskInterface =
      if cfg.grubVersion == 1 then "scsi" else "virtio";
  
    boot.loader.systemd-boot.enable = mkIf (cfg.bootLoader == "systemd-boot") true;
  
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
    ++ optional (cfg.bootLoader == "grub" && cfg.grubVersion == 1) pkgs.grub
    ++ optionals (cfg.bootLoader == "grub" && cfg.grubVersion == 2) [
      pkgs.grub2
      pkgs.grub2_efi
    ];
  
    nix.binaryCaches = mkForce [ ];
    nix.extraOptions = ''
      hashed-mirrors =
      connect-timeout = 1
    '';
  };
}
