{ config, pkgs, ... }:

{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        monitor = 0;
        geometry = "300x10-30+55";
        # Position the notification in the top right corner
        origin = "top-right";
        # Offset from the origin
        offset = "10x50";
        # Scale factor. It is auto-detected if value is 0.
        scale = 0;
        allow_markup = true;
        format = "<b>%a</b>\n %s\n%b";
        word_wrap = true;
        ignore_newline = false;
      };
    };
  };

}
