{ lib }:

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

  installScript = { nodes, createPartitions }:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (machine: module: ''
        ${machine}.start()

        with subtest("Assert readiness of login prompt"):
            ${machine}.succeed("echo hello")

        with subtest("Wait for hard disks to appear in /dev"):
            ${machine}.succeed("udevadm settle")

        ${createPartitions.machine or ""}

        ${machine}.shutdown()
      '') nodes
    );

  mkTest = { nodes, testScript, installerConfig, createPartitions }:
    {
      # nodes = lib.mapAttrs (machine: module: {
      #   imports = [ module extraConfig ];
      # }) nodes; 

      # Make every node an "installer" first, so we can create appropriate
      # partitions, then boot into node-specific config.
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
          (installScript { inherit nodes createPartitions; })
          testScript
        ];
    };
}
