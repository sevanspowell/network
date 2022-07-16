{ modulesPath, config, pkgs, lib, inputs, ... }:

{
  # Base dev machine
  users.users.dev.createHome = true;
  users.users.dev.extraGroups = [];
  users.users.dev.group = "users";
  users.users.dev.isNormalUser = true;
  users.users.dev.uid = 1000;

  environment.systemPackages = (with pkgs; [
    git
  ]);
}
