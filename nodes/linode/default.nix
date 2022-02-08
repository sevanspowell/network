{ ... }:

{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    {
      boot.loader.grub.device = "/dev/vda";
    }
  ];
}
