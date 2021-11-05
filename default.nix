{ pkgs ? import ./nix {},  system ? "x86_64-linux" }:

let
  nixpkgs = pkgs.lib.cleanSource pkgs.path;

  vmConfig = configuration: (import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system ;
    modules = [
      configuration
      "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
      "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
      {
        users.mutableUsers = false;
        users.extraUsers.sam.initialPassword = "sam";
      }
    ];
  });

  isoConfig = (import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
      "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    ];
  });

  installerEnv = configuration:
    let
      evaluated = import "${nixpkgs}/nixos/lib/eval-config.nix" {
        inherit system ;
        modules = [ configuration ];
      };

      isoImage = isoConfig.config.system.build.isoImage;
      isoName = isoConfig.config.isoImage.isoName;

      systemName = evaluated.config.system.name;

    in
      pkgs.writeShellScriptBin "run-${systemName}-vm" ''
        ${(vmConfig configuration).config.system.build.vm}/bin/run-${systemName}-vm -boot d -cdrom ${isoImage}/iso/${isoName}
      '';

  partitionDiskScript = import ./nixos/scripts/partition/simple.nix {
    inherit pkgs;
    disk = "/dev/vda";
  };
in
rec {
  vm = (vmConfig ./nodes/plum/configuration.nix).config.system.build.vm;
  iso = isoConfig.config.system.build.isoImage;
  install = installerEnv ./nodes/plum/configuration.nix;

  # nix-build -A tests.installer.x86_64-linux.test.driverInteractive
  tests = pkgs.callPackage ./nixos/tests/default.nix { inherit system; };

  hardware-config = pkgs.callPackage ./nixos/lib/vm-hardware-config.nix {
    inherit system partitionDiskScript;
  };

  # partition-disks && install-nixos
  # $ qemu-kvm -drive file=./nixos.qcow2,if=virtio,werror=report -cpu max -m 1024 -net nic,netdev=user.0,model=virtio -netdev user,id=user.0,hostfwd=tcp::2221-:22,hostfwd=tcp::8080-:80 -soundhw all
  # $ ssh -X -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no sam@localhost -p 2221
  # <3
  installer-test-helper = pkgs.callPackage ./nixos/lib/vm-install-test.nix {
    inherit system partitionDiskScript;
    diskSize = 25 * 1024;
  };

  # Rebuild on system:
  # pathToConfig=$(nix-build --no-out-link -A nodes.plum.config.system.build.toplevel)
  # nix-env -p /nix/var/nix/profiles/system --set $pathToConfig
  # $pathToConfig/bin/switch-to-configuration switch

  # Yubikey passthru:
  # Bus 001 Device 008: ID 1050:0407 Yubico.com Yubikey 4/5 OTP+U2F+CCID
  # QEMU_OPTS="-usb -device usb-host,hostbus=1,hostaddr=3"
  # QEMU_OPTS=$(lsusb | grep Yubikey | awk '{print "-usb -device usb-host,hostbus="$2",hostaddr="$4}' | sed 's/:$//')
  nodes = {
    orchid = (import "${nixpkgs}/nixos" {
      configuration = { ... }: {
        imports = [
          ./nodes/orchid/default.nix
          {
            users.mutableUsers = false;
            users.extraUsers.sam.initialPassword = "";
            users.extraUsers.root.initialPassword = "";
          }
        ];
      };
    });

    plum = (import ./nixos {
      inherit pkgs;
      configuration = { modulesPath, config, ... }: {
        imports = [
          ./nodes/plum/default.nix
          # ./nixos/modules/closure.nix
          # ./nixos/modules/qemu-vm-base.nix
          # {
          #   environment.systemPackages = [
          #     (pkgs.writeShellScriptBin "partition-disks" partitionDiskScript)
          #   ];
          # }
          {
            users.mutableUsers = false;
            users.extraUsers.sam.initialPassword = "";
            users.extraUsers.root.initialPassword = "";
          }
          # only in vm with useBootLoader = true
          # {
          #   system.build.tarball = pkgs.callPackage "${nixpkgs}/nixos/lib/make-system-tarball.nix" {
          #     storeContents = [
          #       {
          #         symlink = "/bin/init";
          #         object = "${config.system.build.toplevel}/init";
          #       }
          #     ];
          #     contents = [];
          #     compressCommand = "cat";
          #     compressionExtension = "";
          #   };

          #   # Install new init script; this ensures that /init is updated after every
          #   # `nixos-rebuild` run on the machine (the kernel can run init from a
          #   # symlink).
          #   system.activationScripts.installInitScript = ''
          #     ln -fs $systemConfig/init /bin/init
          #   '';

          #   boot.postBootCommands =
          #     # Import Nix DB, so that nix commands work and know what's installed.
          #     # The `rm` ensures it's done only once; `/nix-path-registration`
          #     # is a file created in the tarball by `make-system-tarball.nix`.
          #     ''
          #     echo "REACHED"
          #     if [ -f /nix-path-registration ]; then
          #       echo "${config.system.build.tarball}"
          #       ${config.nix.package.out}/bin/nix-store --load-db --option build-use-substitutes false < /nix-path-registration && rm /nix-path-registration
          #     fi
          #     ''
          #     +
          #     # Create the system profile to make nixos-rebuild happy
          #     ''
          #       ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
          #     '';
          # }

        ];
      };
    });
  };
}
