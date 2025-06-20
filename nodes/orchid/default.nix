{ nixpkgs, sops-nix, home-manager, ... } @ inputs:
{
  system = "x86_64-linux";

  modules = [
    { _module.args.inputs = inputs; }
    sops-nix.nixosModules.sops
    home-manager.nixosModules.default
    {
      boot.initrd.luks.devices = {
        nixos-enc = { device = "/dev/disk/by-uuid/8cbcb189-ce25-460b-b980-d67ed7e7cc4c"; preLVM = true; };
      };
    }
    ./configuration.nix
    ./hardware-configuration.nix
  ];
}
