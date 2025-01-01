inputs:

{ modulesPath, lib, pkgs, config, ... }:

let
  sshKeys = lib.flatten (lib.attrValues (import ../../ssh-keys.nix));
in
{
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix"
              "${modulesPath}/../maintainers/scripts/ec2/amazon-image.nix"
            ];

  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];

  # https://github.com/NixOS/nixpkgs/issues/109389
  networking.dhcpcd.denyInterfaces = [ "veth*" ];

  # Grow root partition if we resize the EBS attached storage.
  boot.growPartition = true;

  environment.systemPackages = (with pkgs; [
    git
    ripgrep
    tree
    vim
    wget
  ]);

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  users.extraUsers.dev = {
    createHome = true;
    extraGroups = ["wheel" "video" "audio" "disk" "networkmanager" ];
    group = "users";
    home = "/home/dev";
    isNormalUser = true;
    uid = 1000;
    openssh.authorizedKeys.keys = sshKeys;
  };

  users.users.root.openssh.authorizedKeys.keys = sshKeys;

  nix.settings.substituters = [
    "https://cache.nixos.org"
    # "https://cache.zw3rk.com"
    "https://cache.iog.io"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    # "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
  ];

  nix = {
    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "21.11"; # Did you read the comment?
}
