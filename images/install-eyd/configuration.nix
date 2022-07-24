{ config, pkgs, modulesPath, inputs, ... }:

let
  install-eyd = inputs.self.packages.x86_64-linux.install-eyd;
in

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/channel.nix"
  ];

  environment.systemPackages = with pkgs; [
    vim
    gparted
    install-eyd
  ];
}
