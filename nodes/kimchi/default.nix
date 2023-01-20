{ nixpkgs, sops-nix, home-manager, ... } @ inputs:

{
  system = "aarch64-linux";

  modules = [
    { _module.args.inputs = inputs; }
    sops-nix.nixosModules.sops
    home-manager.nixosModule
    ./configuration.nix
    ./hardware-configuration.nix
  ];
}
