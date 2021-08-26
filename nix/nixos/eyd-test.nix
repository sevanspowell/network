# Base configuration for a machine running an eyd-test
{ config, lib, pkgs, modulesPath, ... }:

with lib;

let
  cfg = config.eyd-test;
in
{
  imports = [ "${modulesPath}/testing/test-instrumentation.nix" ];

  options = {
    eyd-test = {
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

      grubDevice = mkOption {
        type = types.string;
        default = "/dev/vda";
      };
  
      grubUseEfi = mkOption {
        type = types.boolean;
        default = false;
        description = ''
          Configure grub to use UEFI or not.
        '';
      };
  
      grubIdentifier = mkOption {
        type = types.string;
        default = "uuid";
      };

      forceGrubReinstallCount = mkOption {
        type = types.int;
        default = 0;
      };
    };
  };

  config = mkMerge [
    {
      # To ensure that we can rebuild the grub configuration on the nixos-rebuild
      system.extraDependencies = with pkgs; [ stdenvNoCC ];

      hardware.enableAllFirmware = lib.mkForce false;
    }

    (mkIf (cfg.bootLoader == "grub") (mkMerge [
      {
        boot.loader.grub.version = "${toString cfg.grubVersion}"
        boot.loader.grub.extraConfig = "serial; terminal_output serial";
        boot.loader.grub.configurationLimit = 100 + ${toString cfg.forceGrubReinstallCount};
      }

      (mkIf (cfg.grubVersion == 1) {
        {
          boot.loader.grub.splashImage = null;
        }
      })

      (mkIf (cfg.grubUseEfi == true) {
        boot.loader.grub.device = "nodev";
        boot.loader.grub.efiSupport = true;
        boot.loader.grub.efiInstallAsRemovable = true; # XXX: needed for OVMF?
      })

      (mkIf (cfg.grubUseEfi == false) {
        boot.loader.grub.device = "${cfg.grubDevice}";
        boot.loader.grub.fsIdentifier = "${cfg.grubIdentifier}";
      })

    ]))

    (mkIf (cfg.bootLoader == "systemd-boot") {
      boot.loader.systemd-boot.enable = true;
    })
  ];
}
