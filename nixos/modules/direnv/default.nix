{ config, pkgs, lib, ... }:
{
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
    # programs.direnv.nix-direnv.enableFlakes = true;
  };

  nix.extraOptions = ''
    keep-outputs = true
    keep-derivations = true
  '';
}
