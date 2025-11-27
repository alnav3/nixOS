{ config, pkgs, ... }:
let
  # Read the script from the flake's scripts directory
  ip-monitor-script = pkgs.writeScriptBin "ip-monitor" (builtins.readFile ./scripts/ip-monitor.sh);
in
{

  # Create the systemd user service
  systemd.user.services.ip-monitor = {
    description = "IP Address Monitor Service";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "default.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${ip-monitor-script}/bin/ip-monitor";
      Restart = "always";
      RestartSec = 10;

      Environment = [
        "DISPLAY=:0"
        "XDG_RUNTIME_DIR=/run/user/1000"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
      ];

      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Required dependencies
  environment.systemPackages = with pkgs; [
    curl
    dnsutils
    libnotify
    ip-monitor-script
  ];
}

