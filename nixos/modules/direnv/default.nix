{ config, pkgs, lib, ... }:
let
  isOlderThan = wantedVersion: package:
    let
      parsedVersion = builtins.parseDrvName package.name;
      pkgVersion = package.version or (parsedVersion.version or 0);
    in (builtins.compareVersions wantedVersion pkgVersion) == 1;
in {
  nixpkgs.overlays = [(self: super: {
    direnv = if isOlderThan "2.28.0" super.direnv
             then (import (self.fetchFromGitHub {
                      owner = "direnv";
                      repo = "direnv";
                      rev = "v2.28.0";
                      sha256 = "0yk53jn7wafklixclka17wyjjs2g5giigjr2bd0xzy10nrzwp7c9";
                  }) {})
             else super.direnv;
  })];

  environment.systemPackages = [ pkgs.direnv ];

  programs = {
    bash.interactiveShellInit = ''
      eval "$(${pkgs.direnv}/bin/direnv hook bash)"
    '';
    zsh.interactiveShellInit = ''
      eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
    '';
    fish.interactiveShellInit = ''
      eval (${pkgs.direnv}/bin/direnv hook fish)
    '';
  };

  home-manager.users.sam = {...}: {
    programs.direnv.enable = true;
    programs.direnv.nix-direnv.enable = true;
    programs.direnv.nix-direnv.enableFlakes = true;
  };

  nix.extraOptions = ''
    keep-outputs = true
    keep-derivations = true
  '';
}
