{ config, pkgs, ... }:
let
  # Path to the launch-game binary
  launch-game-binary = ../scripts/launch-game;
in
{

  # Create the systemd user service
  systemd.user.services.launch-game = {
    description = "Launch Game Service";
    after = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    wantedBy = [ "default.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${launch-game-binary}";
      Restart = "always";
      RestartSec = 5;

      Environment = [
        "DISPLAY=:0"
        "XDG_RUNTIME_DIR=/run/user/1000"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
        "XDG_SESSION_TYPE=wayland"
        "WAYLAND_DISPLAY=wayland-1"
      ];

      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Install the binary in the system packages
  environment.systemPackages = [
    (pkgs.stdenv.mkDerivation {
      name = "launch-game";
      src = launch-game-binary;
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        cp $src $out/bin/launch-game
        chmod +x $out/bin/launch-game
      '';
    })
  ];
}