{ config, pkgs, ... }:
let
  # Path to the launch-game binary
  launch-game-binary = ../scripts/launch-game;
  
  # Create a wrapper script that sets up the environment
  launch-game-wrapper = pkgs.writeShellApplication {
    name = "launch-game-wrapper";
    runtimeInputs = with pkgs; [ steam steam-run ];
    text = ''
      exec "${launch-game-binary}"
    '';
  };
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
      ExecStart = "${launch-game-wrapper}/bin/launch-game-wrapper";
      Restart = "always";
      RestartSec = 5;

      Environment = [
        "DISPLAY=:0"
        "XDG_RUNTIME_DIR=/run/user/1000"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
        "XDG_SESSION_TYPE=wayland"
        "WAYLAND_DISPLAY=wayland-1"
        "PATH=/run/wrappers/bin:/home/alnav/.nix-profile/bin:/etc/profiles/per-user/alnav/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
      ];

      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Install the binary and wrapper in the system packages
  environment.systemPackages = [
    launch-game-wrapper
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