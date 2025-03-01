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
  tuigreet = "${pkgs.greetd.tuigreet}/bin/tuigreet";
  session = "dbus-run-session ${pkgs.hyprland}/bin/Hyprland";
  username = "alnav";
in {
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = lib.mkDefault session;
        user = lib.mkDefault username;
      };
      default_session = {
        command = lib.mkDefault "${tuigreet} --greeting 'Welcome to NixOS!' --asterisks --remember --remember-user-session --time ";
        user = lib.mkDefault username;
      };
    };
  };
}

