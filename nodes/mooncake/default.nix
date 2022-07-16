{ nixpkgs, sops-nix, home-manager, cardano-node, cardano-db-sync, ... } @ inputs:

{
  system = "x86_64-linux";

  modules = [
    { _module.args.inputs = inputs; }
    ./configuration.nix
    ./lib/base.nix
    ./lib/ssh.nix
  ];
}
