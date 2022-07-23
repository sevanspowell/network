# Provides required configuration to forward the gpg-agent socket from this
# machine to a client, allowing the client to use its own gpg-agent (yubikey,
# ssh-agent, etc.) on this machine.
#
# To use such features, the client must connect to the machine with the
# following ssh command (or similar):
#
# ssh user@host -Rremote_socket:local_socket
#
# E.g.
#
# [client]$ ssh user@host \
#   -R/run/user/1000/gnupg/S.gpg-agent:/run/user/1000/gnupg/S.gpg-agent.extra \
#   -R/run/user/1000/gnupg/S.gpg-agent.ssh:/run/user/1000/gnupg/S.gpg-agent.ssh
#
# Note that we forward to the client's local "extra" and "ssh" socket.
# Forwarding the ssh socket is optional. Note also that the "extra" socket is
# restricted and so commands like "gpg --card-status" won't work on the host.
# This is usually what you want.
#
# Any gpg key you want to use must have it's public key imported and available on the host:
#   gpg --import public.key
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.gpg-passthru;
in
{
  options.gpg-passthru = {
    users = mkOption {
      type = with types; listOf string;
      default = [];
      example = literalExample ''
        [ "root" "dev" ]
      '';
      description = ''
        List of users you wish to enable gpg-passthru for.
      '';
    };
  };

  config = {
    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = true;
      passwordAuthentication = false;
      extraConfig = ''
        StreamLocalBindUnlink yes
      '';
    };

    home-manager.users = listToAttrs (map (user:
      lib.nameValuePair "${user}" {
        services.gpg-agent = {
          enable = true;
          enableSshSupport = true;
          # Pinentry should run on the client
          pinentryFlavor = null;
        };

        programs.gpg = {
          enable = true;

          scdaemonSettings = {
            disable-ccid = true;
            reader-port = "Yubico Yubi";
          };
        };

        # Required for ensuring SSH commands look in the correct place for ssh
        # authorization.
        home.file.".profile".text = ''
          export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
        '';
      }
    ) cfg.users);
  };
}
