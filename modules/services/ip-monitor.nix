{ config, lib, pkgs, ... }:

let
  cfg = config.mymodules.services.ipMonitor;
  ip-monitor-script = pkgs.writeShellApplication {
    name = "ip-monitor";
    runtimeInputs = with pkgs; [ curl dnsutils libnotify coreutils ];
    text = builtins.readFile ../../scripts/ip-monitor.sh;
  };
in
{
  options.mymodules.services.ipMonitor = {
    enable = lib.mkEnableOption "IP address monitor service";
  };

  config = lib.mkIf cfg.enable {
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

    environment.systemPackages = with pkgs; [
      curl
      dnsutils
      libnotify
      ip-monitor-script
    ];
  };
}
