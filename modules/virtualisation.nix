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
