{ config, lib, pkgs, modulesPath, ... }:
with lib;
{
  imports = [
    # "${modulesPath}/profiles/headless.nix"
    "${modulesPath}/profiles/qemu-guest.nix"
  ];


  fileSystems."/" = {
    fsType = "ext4";
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
  };

  boot.loader.grub.enable = false;
  boot.growPartition = true;
  boot.initrd.kernelModules = [ "virtio_scsi" ];
  boot.kernelModules = [ "virtio_pci" "virtio_net" ];
  boot.kernelParams = [ "console=ttyS0,19200n8" "panic=1" "boot.panic_on_fail" ];
  boot.loader.grub.extraConfig = ''
    serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1;
    terminal_input serial;
    terminal_output serial
  '';

  # # Generate a GRUB menu.
  boot.loader.grub.device = "/dev/sda";
  users.extraUsers.root.password = "";

  # boot.loader.timeout = 10;
  # boot.loader.grub.forceInstall = true;

  # # Don't put old configurations in the GRUB menu.  The user has no
  # # way to select them anyway.
  # boot.loader.grub.configurationLimit = 0;

  # # Allow root logins only using SSH keys
  # # and disable password authentication in general
  # services.openssh.enable = true;
  # services.openssh.permitRootLogin = "yes";
  # # services.openssh.passwordAuthentication = mkDefault false;


  # # Force getting the hostname from Linode.
  # networking.hostName = mkDefault "";

  # # Always include cryptsetup so that NixOps can use it.
  # environment.systemPackages = with pkgs; [
  #   cryptsetup
  #   inetutils
  #   mtr
  #   sysstat
  # ];

  # networking.usePredictableInterfaceNames = false;
  # networking.useDHCP = false; # Disable DHCP globally as we will not need it.
  # # required for ssh?
  # networking.interfaces.eth0.useDHCP = true;

  # # GC has 1460 MTU
  # networking.interfaces.eth0.mtu = 1460;
}
