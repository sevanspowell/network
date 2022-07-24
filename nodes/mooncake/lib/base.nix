{ modulesPath, config, pkgs, lib, inputs, ... }:

{
  environment.systemPackages = (with pkgs; [
    git
    # Required for full-featured term, otherwise backspace etc. won't work
    rxvt_unicode.terminfo
  ]);

  # useGlobalPkgs/useUserPackages Required with flakes
  # See https://nix-community.github.io/home-manager/index.html#sec-flakes-nixos-module
  # and https://github.com/divnix/digga/issues/30
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  nix = {
    package = pkgs.nix_2_7;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  nix.binaryCaches = [
    "https://cache.nixos.org"
    "https://cache.iog.io"
  ];
  nix.binaryCachePublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
  ];

  # Base dev machine
  users.users.dev = {
    createHome = true;
    extraGroups = ["wheel"];
    group = "users";
    isNormalUser = true;
    uid = 1000;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425"
    ];
  };
}
