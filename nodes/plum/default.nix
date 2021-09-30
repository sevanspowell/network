# let
#   partitionDiskScript = import ../../nixos/scripts/partition/simple.nix {
#     inherit pkgs;
#     disk = "/dev/vda";
#   };
# in
{ system, pkgs, ... }:

let
  x = "${pkgs.callPackage ../../nixos/lib/vm-hardware-config.nix {
      diskSize = 25 * 1024;
      inherit system;
      partitionDiskScript = null;
    }}/hardware-configuration.nix";
in
{
  imports = [
    ./configuration.nix
    ../../nixos/modules/qemu-vm-base.nix
    x
  ];
}
