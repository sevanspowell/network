{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.virtualisation.linodeImage;

  defaultConfigFile = pkgs.writeText "configuration.nix" ''
    { ... }:
    {
      imports = [
        ${./linode-image.nix}
      ];
    }
  '';

  nixpkgs = pkgs.lib.cleanSource pkgs.path;
in
{

  imports = [ ./linode-config.nix ];

  options = {
    virtualisation.linodeImage.diskSize = mkOption {
      type = with types; int;
      default = 1536;
      description = ''
        Size of disk image. Unit is MB.
      '';
    };

    virtualisation.linodeImage.configFile = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        A path to a configuration file which will be placed at `/etc/nixos/configuration.nix`
        and be used when switching to a new configuration.
        If set to `null`, a default configuration is used, where the only import is
        `<linode-image.nix>`.
      '';
    };
  };

  #### implementation
  config = {
    system.build.linodeImage = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
      name = "linode-image";
      postVM = ''
        PATH=$PATH:${with pkgs; lib.makeBinPath [ gnutar gzip ]}
        pushd $out
        mv $diskImage disk.raw
        tar -Szcf nixos-image-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.raw.gz disk.raw
        rm $out/disk.raw
        popd
      '';
      format = "raw";
      partitionTableType = "none";
      configFile = if cfg.configFile == null then defaultConfigFile else cfg.configFile;
      inherit (cfg) diskSize;
      inherit config lib pkgs;
    };

  };

}
