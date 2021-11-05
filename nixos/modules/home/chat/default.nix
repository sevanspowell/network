{ config, pkgs, ... }:

{
  # NOTE: If you have issues, try clearing local data (default
  # ~/.local/share/pantalaimon) (e.g. "UnboundLocalError: local variable 'token' referenced before assignment")
  imports = [
    ./pantalaimon.nix
  ];

  services.pantalaimon = {
    enable = true;
    settings = {
        Default = {
          LogLevel = "Debug";
          SSL = true;
        };
        adrestia-matrix = {
          Homeserver = "https://matrix.adrestia.iohkdev.io";
          ListenAddress = "localhost";
          ListenPort = "8008";
        };
        local-matrix = {
          Homeserver = "https://matrix.org";
          ListenAddress = "localhost";
          ListenPort = "8010";
        };
      };
  };
}
