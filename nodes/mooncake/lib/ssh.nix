let
  user = "dev";
  pubKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425"
  ];
in
{
  # ssh : user [pubKeys]
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;
  # Automatically remove stale sockets when connecting to the remote machine.
  services.openssh.extraConfig = ''
    StreamLocalBindUnlink yes
  '';
  users.users."${user}".openssh.authorizedKeys.keys = pubKeys;
}
