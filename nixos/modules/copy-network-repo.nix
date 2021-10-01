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
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
      };
      script = ''
      if ! [ -e /var/lib/nixos/did-network-repo-copy ]; then
        tmp=$(mktemp -d)
        tmp_git=$(mktemp -d)

        cp -r ${networkSrc}/* $tmp

        ${pkgs.git}/bin/git clone https://github.com/sevanspowell/network.git $tmp_git
        cp -r $tmp_git/.git $tmp/.git

        chown -R root:users $tmp
        ${pkgs.findutils}/bin/find $tmp -type f -exec chmod ug+rw {} ";"
        ${pkgs.findutils}/bin/find $tmp -type d -exec chmod ug+rwx {} ";"

        mkdir -p /srv/
        mv $tmp /srv/network

        touch /var/lib/nixos/did-network-repo-copy
      fi
      '';
    };
  };
}
