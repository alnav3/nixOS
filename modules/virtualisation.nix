{pkgs, ...}:
{
    systemd.services.docker-custom-net = {
        description = "Create custom Docker network";
        wantedBy = [ "multi-user.target" ];
        before = [ "docker-n8n.service" ];
        serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.bash}/bin/sh -c '${pkgs.docker}/bin/docker network inspect custom-net >/dev/null 2>&1 || ${pkgs.docker}/bin/docker network create --subnet=172.42.0.0/24 custom-net'";
            RemainAfterExit = true;
        };
    };

    systemd.services.bidirectional-sync = {
        description = "Bidirectional sync between /mnt/containers and /var/containers-data";
        wantedBy = [ "timers.target" ];
        serviceConfig = {
            Type = "oneshot";
            StandardOutput = "journal";
            StandardError  = "journal";
            Environment = "HOME=/root";

            # Ensure mount is available before starting.
            ExecStart = ''
                ${pkgs.unison}/bin/unison /mnt/containers /var/containers-data \
                -auto -batch -times -prefer newer -copyonconflict -perms 0 \
                -logfile /var/log/unison/containers.log -silent
            '';
        };

        unitConfig = {
            RequiresMountsFor = [ "/mnt/containers" "/var/containers-data" ];
            After = "network-online.target mnt-containers.mount";
            Wants = [ "network-online.target" ];
        };
    };

    systemd.timers.bidirectional-sync = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
            # Run daily at 04:00
            OnCalendar = "04:00";
            Persistent = true;
            RandomizedDelaySec = "1h";
        };
    };

    boot.enableContainers = true;
  # docker config
  virtualisation = {

    docker = {
      enable = true;
      rootless = {
          enable = true;
          setSocketVariable = true;
      };
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [
          "--filter=until=24h"
          "--filter=label!=important"
        ];
      };
    };
  };
  virtualisation.oci-containers = {
    backend = "docker";
  };

}
