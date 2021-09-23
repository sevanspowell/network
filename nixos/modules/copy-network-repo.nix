{ pkgs, ... }:

let
  networkSrc = builtins.fetchGit ../..;
  srcPkg = pkgs.runCommand "copy-network-repo" {} ''
    mkdir $out
    cp -r ${networkSrc}/* $out
  '';
in
{
  config = {
    systemd.services.copy-network-repo = {
      description = "Copy NixOS configuration repository to machine";
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
      if ! test -e "/root/network"; then
        mkdir /root/network
        cp -r ${networkSrc}/* /root/network
      fi
      '';
    };
  };
}
