{ modulesPath, config, pkgs, lib, inputs, ... }:

{
  imports =
    [
      ./direnv.nix
    ];

  direnv.users = [ "root" "dev" ];
}
