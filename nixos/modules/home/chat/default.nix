{ config, pkgs, ... }:

{
  # NOTE: If you have issues, try clearing local data (default
  # ~/.local/share/pantalaimon) (e.g. "UnboundLocalError: local variable 'token' referenced before assignment")
  imports = [
    # ./pantalaimon.nix
  ];

  home.packages = [
    (pkgs.python3Packages.callPackage ./pkg/keyrings-sagecipher.nix {})
  ];

  # services.pantalaimon = {
  #   enable = true;
  #   settings = {
  #       Default = {
  #         LogLevel = "Debug";
  #         SSL = true;
  #       };
  #       adrestia-matrix = {
  #         Homeserver = "https://matrix.adrestia.iohkdev.io";
  #         ListenAddress = "localhost";
  #         ListenPort = "8008";
  #       };
  #       local-matrix = {
  #         Homeserver = "https://matrix.org";
  #         ListenAddress = "localhost";
  #         ListenPort = "8010";
  #       };
  #     };
  # };

  # systemd.user.services.pantalaimon.Service.Environment = "PYTHON_KEYRING_BACKEND=sagecipher.keyring.Keyring";
}
