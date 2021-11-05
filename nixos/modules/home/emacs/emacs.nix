self: super:

let
  mkGitEmacs = namePrefix: jsonFile: { ... }@args:
    let
      repoMeta = super.lib.importJSON jsonFile;
      fetcher =
        if repoMeta.type == "savannah" then
          super.fetchFromSavannah
        else if repoMeta.type == "github" then
          super.fetchFromGitHub
        else
          throw "Unknown repository type ${repoMeta.type}!";
    in
      builtins.foldl'
        (drv: fn: fn drv)
        self.emacs
        [

          (drv: drv.override ({ srcRepo = true; } // args))

          (
            drv: drv.overrideAttrs (
              old: {
                name = "${namePrefix}-${repoMeta.version}";
                inherit (repoMeta) version;
                src = fetcher (builtins.removeAttrs repoMeta [ "type" "version" ]);

                patches = [
                ];
                postPatch = old.postPatch + ''
                          substituteInPlace lisp/loadup.el \
                          --replace '(emacs-repository-get-version)' '"${repoMeta.rev}"' \
                          --replace '(emacs-repository-get-branch)' '"master"'
                          '';

              }
            )
          )

          # --with-nativecomp was changed to --with-native-compilation
          # Remove this once 21.05 is released
          (drv: if drv.passthru.nativeComp && self.lib.elem "--with-nativecomp" drv.configureFlags then drv.overrideAttrs(old: {
            configureFlags = builtins.map (flag: if flag == "--with-nativecomp" then "--with-native-compilation" else flag) old.configureFlags;
          }) else drv)

          # reconnect pkgs to the built emacs
          (
            drv: let
              result = drv.overrideAttrs (old: {
                passthru = old.passthru // {
                  pkgs = self.emacsPackagesFor result;
                };
              });
            in result
          )
        ];

  emacs28 = mkGitEmacs "emacs28" ./emacs28.json { };
in
{
  inherit emacs28;
}
