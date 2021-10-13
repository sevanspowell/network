{ ... }:

{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    {
      boot.loader.grub.device = "/dev/vda";
    }
    # In vmWithBootLoader
    # {
    #   boot.loader.grub.device = "/dev/vdb";
    # }
  ];
}
