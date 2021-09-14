{ pkgs
, system
# , configuration
, partitionDiskScript
, diskSize ? (8 * 1024)
}:

let
  nixpkgs = pkgs.lib.cleanSource pkgs.path;

  # Configuration for "installer" machine
  installerConfiguration = import ../modules/installer-vm {
    inherit diskSize;
  };

  evalConfig = modules: import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system modules;
  };

  installerConfig = evalConfig [
    installerConfiguration
    {
      environment.systemPackages = [
        partitionDiskScript
      ];
    }
  ];

  # machineConfig = evalConfig [
  #   configuration
  #   "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
  # ];

in
  installerConfig.config.system.build.vm
