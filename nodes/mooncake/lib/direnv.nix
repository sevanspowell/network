{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.direnv;
in
{
  options.direnv = {
    users = mkOption {
      type = with types; listOf string;
      default = [];
      example = literalExample ''
        [ "root" "dev" ]
      '';
      description = ''
        List of users you wish to enable direnv for.
      '';
    };
  };

  config = {
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

    home-manager.users = listToAttrs (map (user:
      lib.nameValuePair "${user}" {
        programs.direnv.enable = true;
        programs.direnv.nix-direnv.enable = true;
        # programs.direnv.nix-direnv.enableFlakes = true;
      }
    ) cfg.users);

    nix.extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };
}
