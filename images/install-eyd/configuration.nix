{ config, pkgs, modulesPath, inputs, ... }:

let
  install-eyd = inputs.self.packages."${pkgs.system}".install-eyd;
  authorizedSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425";
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

  isoImage.storeContents = [
    inputs.self.nixosConfigurations.client.config.system.build.toplevel
  ];

  environment.etc.ssh-key = {
    text = "${authorizedSSHKey}";
    mode = "0444";
  };
}
