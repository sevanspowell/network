{ substituteAll
, bzip2
, coreutils
, less
, lib
, writeScriptBin
, runtimeShell
}:
let
  nix-ll = writeScriptBin "nix-ll" ''
    #!${runtimeShell}
    PATH=$PATH:${lib.makeBinPath [ bzip2 coreutils less ]}

    basedir="/nix/var/log/nix/drvs"
    subdir=$(ls $basedir -t1A | head -n1)
    file=$(ls -t1A $basedir/$subdir | head -n1)

    bzcat $basedir/$subdir/$file | less
  '';

in nix-ll
