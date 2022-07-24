{ modulesPath, config, pkgs, lib, inputs, ... }:

let
  user = "dev";
  pubKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425"
  ];
in
{
  # Unknown
  networking.hostName = "mooncake";

  # TODO Remove
  users.users.dev.initialPassword = "moon";
  users.users.root.initialPassword = "moon";
}
