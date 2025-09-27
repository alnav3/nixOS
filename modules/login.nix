#{pkgs, ...}:
#{
#  services.greetd = {
#    enable = true;
#    settings = rec {
#      initial_session = {
#        command = "${pkgs.hyprland}/bin/Hyprland";
#        user = "alnav";
#      };
#      default_session = initial_session;
#    };
#  };
#}
{ pkgs, lib, ... }: let
  tuigreet = "${pkgs.tuigreet}/bin/tuigreet";
  session = "dbus-run-session ${pkgs.hyprland}/bin/Hyprland";
  username = "alnav";
in {
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = session;
        user = username;
      };
      default_session = {
        command = "${tuigreet} --greeting 'Welcome to NixOS!' --asterisks --remember --remember-user-session --time ";
        user = username;
      };
    };
  };
}

