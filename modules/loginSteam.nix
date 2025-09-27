{ pkgs, lib, ... }: let
  tuigreet = "${pkgs.tuigreet}/bin/tuigreet";
  session = "start-gamescope-session";
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


