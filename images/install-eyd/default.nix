system: { nixpkgs, ... } @ inputs:

{
  inherit system;

  modules = [
    { _module.args.inputs = inputs; }
    ./configuration.nix
  ];
}
