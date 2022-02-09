{ nixpkgs, sops-nix, home-manager, cardano-node, cardano-db-sync, ... } @ inputs:

{
  system = "x86_64-linux";

  modules = [
    { _module.args.inputs = inputs; }
    sops-nix.nixosModules.sops
    home-manager.nixosModule
    cardano-node.nixosModules.cardano-node
    cardano-db-sync.nixosModules.cardano-db-sync
    {
      boot.initrd.luks.devices = {
        nixos-enc = { device = "/dev/disk/by-uuid/8cbcb189-ce25-460b-b980-d67ed7e7cc4c"; preLVM = true; };
      };
    }
    ./configuration.nix
    ./hardware-configuration.nix
  ];
}
