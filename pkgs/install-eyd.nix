{ writeScriptBin }:

writeScriptBin "install-eyd" (builtins.readFile ./install-eyd.sh)
