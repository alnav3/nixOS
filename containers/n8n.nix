{ lib, pkgs, ... }:

let
  myContainerIPs = {
    n8n = "172.42.0.42";
    postgres = "172.42.0.43";
  };
in
{
  sops.secrets."n8n.env" = { };
  virtualisation.oci-containers.containers = {
    n8n_postgres = {
        image = "postgres:15-alpine";
        environmentFiles = [ "/run/secrets/n8n.env" ]; # expects POSTGRES_* etc or DB_* depending on image
        volumes = [
            "/var/containers-data/n8n_postgres:/var/lib/postgresql/data"
        ];
        extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.postgres}" ];
    };
    n8n = {
      image = "docker.io/n8nio/n8n:latest";
      environment = {
        TZ = "Etc/UTC";
        N8N_PORT = "5678";
        N8N_HOST = "0.0.0.0";
        N8N_SECURE_COOKIE = "false";
        WEBHOOK_URL = "http://n8n.home";
        GENERIC_TIMEZONE = "Etc/UTC";
        PUID = "1000";
        PGID = "1000";
        # Fix deprecation warnings
        DB_SQLITE_POOL_SIZE = "3";
        N8N_RUNNERS_ENABLED = "true";
      };
      extraOptions = [
        "--net" "custom-net"
        "--ip" "${myContainerIPs.n8n}"
        "--health-cmd" "wget --no-verbose --tries=1 --spider http://localhost:5678 || exit 1"
        "--health-start-period" "30s"
        "--health-timeout" "5s"
        "--health-interval" "30s"
        "--health-retries" "3"
      ];
      volumes = [
        "/var/containers-data/n8n:/home/node/.n8n"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."n8n.home" = {
    serverName = "n8n.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.n8n}:5678";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support for n8n
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Increase timeouts for long-running workflows
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
      '';
    };
  };
}
