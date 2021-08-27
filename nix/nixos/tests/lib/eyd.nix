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

  installScript = { nodes, installerConfig }:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (machine: module: ''
        ${machine}.start()

        with subtest("Assert readiness of login prompt"):
            ${machine}.succeed("echo hello")

        with subtest("Wait for hard disks to appear in /dev"):
            ${machine}.succeed("udevadm settle")

        ${installerConfig."${machine}".createPartitions or ""}

        with subtest("Create the NixOS configuration"):
            machine.succeed("nixos-generate-config --root /mnt")
            machine.succeed("cat /mnt/etc/nixos/hardware-configuration.nix >&2")
            machine.succeed(
                "${(nodeCfg module).config.system.build.toplevel}/bin/switch-to-configuration test"
            )
            machine.succeed("cat /mnt/etc/nixos/configuration.nix >&2")

        ${machine}.shutdown()
      '') nodes
    );

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
          installerConfig."${machine}".extraInstallerConfig
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
