{ config, pkgs, system, lib, ... }:
let
  nixpkgs = pkgs.lib.cleanSource pkgs.path;

  pythonDict = with lib; params: "\n    {\n        ${concatStringsSep ",\n        " (mapAttrsToList (name: param: "\"${name}\": \"${param}\"") params)},\n    }\n";

  machineConfig = extraConfig: pythonDict ({ qemuFlags = "-m 768"; } // extraConfig);

  isoConfig = (import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
      "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    ];
  });

  iso = isoConfig.config.system.build.isoImage;
  isoName = isoConfig.config.isoImage.isoName;

  extraConfig = {
    cdrom = "${iso}/iso/${iso.isoName}";
  };
in
{
  name = "boot";

  nodes = { };

  testScript =
    ''
        machine = create_machine(${machineConfig extraConfig})
        machine.start()
    '';
}
