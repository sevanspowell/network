{ pkgs, system, lib }:

rec {
  extraConfig = {
    boot.kernelParams = lib.mkAfter [ "console=tty0" ];

    # ZFS
    boot.supportedFilesystems = [ "zfs" ];

    # Using by-uuid overrides the default of by-id, and is unique
    # to the qemu disks, as they don't produce by-id paths for
    # some reason.
    boot.zfs.devNodes = "/dev/disk/by-uuid/";
    networking.hostId = "00000000";

    nix.nixPath =
      [
        "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
        "/nix/var/nix/profiles/per-user/root/channels"
      ];
  };

  installedSystem = installedConfig: (import "${pkgs.path}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [ installedConfig ];
  }).config;
  # config.system.build.toplevel

  # hardwareConfiguration = createPartitionsScript:
  #   (import "${pkgs.path}/nixos/lib/testing-python.nix" { inherit system; }).runInMachine {
  #     drv = pkgs.runCommand "create-partitions" {} ''
  #       ${createPartitionsScript}
  #       nixos-generate-config --root /mnt
  #       echo /mnt/etc/nixos
  #       cp /mnt/etc/nixos/hardware-configuration.nix $out/
  #   '';
  #   machine = { ... }: { };
  # };

  hardwareConfiguration = createPartitionScript:
    (import "${pkgs.path}/nixos/lib/make-disk-image.nix" {
      inherit pkgs lib;
      configFile = ./eyd.nix;
      config = installedSystem {
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
          autoResize = true;
        };

        boot.growPartition = true;
        boot.kernelParams = [ "console=ttyS0" ];
        boot.loader.grub.device = "/dev/vda";
        boot.loader.timeout = 0;
      };

      postVM = ''
          cpfromfs -p -P 1 -t ext4 -i $diskImage /etc/nixos/configuration.nix $out/
      '';
    });

  hardwareConfiguration2 = config: createPartitionScript:
    (import ./mk-eyd-image.nix {
      inherit pkgs lib;
      config = installedSystem config;
      createPartitionScript = createPartitionScript;
      # rootPartition = "1";
      postVM = ''
          cpfromfs -p -P 1 -t ext4 -i $diskImage /etc/nixos/hardware-configuration.nix $out/
      '';
    });
  # hardwareConfiguration = createPartitionScript: pkgs.vmTools.runInLinuxVM (
  #   pkgs.runCommand "generate-hardware-configuration"
  #     { preVM = null;
  #     , buildInputs = with pkgs; [ lkl ];

  # );

  installScript = { nodes, installerConfig }:
    let
      nixosConfigDir = if installerConfig ? nixosConfigDir then installerConfig.nixosConfigDir else "/etc/nixos/";
    in
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (machine: module: ''
          ${machine}.start()

          with subtest("Assert readiness of login prompt"):
              ${machine}.succeed("echo hello")

          with subtest("Wait for hard disks to appear in /dev"):
              ${machine}.succeed("udevadm settle")

          ${installerConfig."${machine}".createPartitions or ""}

          with subtest("Create the NixOS configuration"):
              machine.succeed("nixos-generate-config --root /mnt ${lib.optionalString (installerConfig ? nixosConfigDir) "--dir${nixosConfigDir}"}")
              machine.succeed("cat /mnt/${nixosConfigDir}/hardware-configuration.nix >&2")
              machine.copy_from_host(
                  "${makeConfig { nodeInstallerCfg = installerConfig.machine; } }",
                  "/mnt/${nixosConfigDir}/configuration.nix",
              )
              machine.succeed("cat /mnt/${nixosConfigDir}/configuration.nix >&2")

          with subtest("Perform installation"):
              machine.succeed(
                  "nixos-install -I 'nixos-config=/mnt/${nixosConfigDir}/configuration.nix' < /dev/null >&2"
              )

          ${machine}.shutdown()
        '') nodes
      );

  makeConfig = { nodeInstallerCfg }:
    pkgs.writeText "configuration.nix" ''
      { config, lib, pkgs, modulesPath, ... }:

      { imports =
          [ ./hardware-configuration.nix
            <nixpkgs/nixos/modules/testing/test-instrumentation.nix>
          ];

        # To ensure that we can rebuild the grub configuration on the nixos-rebuild
        system.extraDependencies = with pkgs; [ stdenvNoCC ];

        ${lib.optionalString (nodeInstallerCfg.bootLoader == "grub") ''
          boot.loader.grub.version = ${toString nodeInstallerCfg.grubVersion};
          ${lib.optionalString (nodeInstallerCfg.grubVersion == 1) ''
            boot.loader.grub.splashImage = null;
          ''}

          boot.loader.grub.extraConfig = "serial; terminal_output serial";
          ${if nodeInstallerCfg.grubUseEfi then ''
            boot.loader.grub.device = "nodev";
            boot.loader.grub.efiSupport = true;
            boot.loader.grub.efiInstallAsRemovable = true; # XXX: needed for OVMF?
          '' else ''
            boot.loader.grub.device = "${nodeInstallerCfg.grubDevice}";
            boot.loader.grub.fsIdentifier = "${nodeInstallerCfg.grubIdentifier}";
          ''}

          boot.loader.grub.configurationLimit = 100 + ${toString nodeInstallerCfg.forceGrubReinstallCount};
        ''}

        ${lib.optionalString (nodeInstallerCfg.bootLoader == "systemd-boot") ''
          boot.loader.systemd-boot.enable = true;
        ''}

        hardware.enableAllFirmware = lib.mkForce false;

        ${nodeInstallerCfg.extraInstallerConfig}
      }
    '';

   nodeCfg = configuration: import "${pkgs.path}/nixos/lib/eval-config.nix" {
     inherit system;
     modules = [ configuration ];
     baseModules =  (import "${pkgs.path}/nixos/modules/module-list.nix") ++
       [ "${pkgs.path}/nixos/modules/virtualisation/qemu-vm.nix"
         "${pkgs.path}/nixos/modules/testing/test-instrumentation.nix" # !!! should only get added for automated test runs
         { key = "no-manual"; documentation.nixos.enable = false; }
         { key = "no-revision";
           # Make the revision metadata constant, in order to avoid needless retesting.
           # The human version (e.g. 21.05-pre) is left as is, because it is useful
           # for external modules that test with e.g. nixosTest and rely on that
           # version number.
           config.system.nixos.revision = lib.mkForce "constant-nixos-revision";
         }
         # { key = "nodes"; _module.args.nodes = nodes; }
       ];
   };

  mkTest = { nodes, testScript, installerConfig }:
    {
      # nodes = lib.mapAttrs (machine: module: {
      #   imports = [ module extraConfig ];
      # }) nodes;

      # Make every node an "installer" first, so we can create appropriate
      # partitions, then boot into node-specific config in the test script.
      nodes = lib.mapAttrs (machine: module: {
        imports = [
          ../../installer-test.nix
          # installerConfig."${machine}".extraInstallerConfig
        ];

        installer-test = {
          inherit (installerConfig."${machine}") bootLoader grubVersion;
        };
      }) nodes;

      testScript =
        lib.concatStringsSep "\n" [
          (installScript { inherit nodes installerConfig ; })
          testScript
        ];
    };
}
