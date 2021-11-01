# Source: https://source.mcwhirter.io/craige/mio-ops/commit/9c2f233273237ecf0e81257130000ac45cf75645
{ config, pkgs, lib, ... }:

{

  environment.systemPackages = with pkgs; [
    aspell                     # Required for spell checking in weechat
    aspellDicts.en             # Required for spell checking in weechat
    aspellDicts.en-computers   # Required for spell checking in weechat
    aspellDicts.en-science     # Required for spell checking in weechat
    (weechat.override {
      configure = { availablePlugins, ... }: with weechatScripts;
        let
          weechat-notify-send' = weechat-notify-send.overrideAttrs (oldAttrs: {
            installPhase = oldAttrs.installPhase + ''
                substituteInPlace $out/share/notify_send.py \
                    --replace "'/usr/share/icons/hicolor/32x32/apps/weechat.png'" \
                              "'${weechat}/share/icons/hicolor/32x32/apps/weechat.png'"
            '';
          });

          weechat-matrix' = weechat-matrix.overrideAttrs (oldAttrs: rec {
            version = "0.3.0";
            src = fetchFromGitHub {
                      owner = "poljar";
                      repo = "weechat-matrix";
                      rev = version;
                      hash = "sha256-o4kgneszVLENG167nWnk2FxM+PsMzi+PSyMUMIktZcc=";
                  };
          });
        in
          {
            plugins = with availablePlugins; [
              lua
              perl
              (python.withPackages (ps: with ps; [
                dbus-python
                websocket_client    # Required by wee-slack
                weechat-matrix'     # https://github.com/NixOS/nixpkgs/pull/79669#issuecomment-584249420
                weechat-notify-send'
              ]))
            ];
            scripts = [
              # wee-slack          # A WeeChat plugin for Slack.com
              weechat-autosort     # Automatically or manually keep your buffers sorted
              weechat-matrix'      # Weechat communication over the Matrix protocol
              weechat-otr          # WeeChat script for Off-the-Record messaging
              weechat-notify-send' # Weechat script for notifications
            ];
          };
    })
    weechatScripts.weechat-matrix   # Weechat communication over the Matrix protocol
  ];

}
