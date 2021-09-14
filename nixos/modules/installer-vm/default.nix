{ diskSize }:

# Simple configuration for a virtualized installer. Mimics a boot from ISO by
# booting off /dev/vdb and allowing user to make full use of /dev/vda
{ config, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/installation-device.nix"
    "${modulesPath}/profiles/base.nix"
    "${modulesPath}/virtualisation/qemu-vm.nix"
  ];

  # Builds stuff in the VM, needs more juice
  virtualisation.cores = 8;
  virtualisation.memorySize = 1536;

  # This will be the disk we partition (/dev/vda)
  virtualisation.diskSize = diskSize;
  # This will be the disk we boot from
  virtualisation.emptyDiskImages = [
    # Small root disk for installer
    512
  ];
  # Boot off root disk
  virtualisation.bootDevice = "/dev/vdb";

  nix.binaryCaches = pkgs.lib.mkForce [ ];
  nix.extraOptions = ''
    hashed-mirrors =
    connect-timeout = 1
  '';
}
