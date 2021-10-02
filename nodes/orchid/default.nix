{ ... }:

{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    {
      boot.initrd.luks.devices = {
        nixos-enc = { device = "/dev/disk/by-uuid/8cbcb189-ce25-460b-b980-d67ed7e7cc4c"; preLVM = true; };
      };
    }
  ];
}
