{ lib, pkgs, config, ... }:

let
  myContainerIPs = {
    infisical = "172.42.0.80";
    infisical_redis = "172.42.0.81";
    infisical_postgres = "172.42.0.82";
  };
in
{
  sops.secrets."infisical.env" = { };

  virtualisation.oci-containers.containers = {
    infisical = {
      image = "infisical/infisical:latest";
      environment = {
        NODE_ENV = "production";
        PORT = "8080";
        REDIS_URL = "redis://${myContainerIPs.infisical_redis}:6379";
        SITE_URL = "http://infisical.home";
        TELEMETRY_ENABLED = "false";
      };
      environmentFiles = [ "/run/secrets/infisical.env" ];
      volumes = [
        "/var/containers-data/infisical:/app/data"
      ];
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.infisical}" ];
      ports = [ "8080:8080" ];
      dependsOn = [ "infisical_redis" "infisical_postgres" ];
    };

    infisical_redis = {
      image = "redis:7.2-alpine";
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.infisical_redis}" ];
      volumes = [
        "/var/containers-data/infisical/redis:/data"
      ];
      cmd = [ "redis-server" "--appendonly" "yes" ];
    };

    infisical_postgres = {
      image = "postgres:15-alpine";
      environmentFiles = [ "/run/secrets/infisical.env" ];
      environment = {
        POSTGRES_INITDB_ARGS = "--encoding=UTF8 --lc-collate=C --lc-ctype=C";
      };
      volumes = [
        "/var/containers-data/infisical/postgres:/var/lib/postgresql/data"
      ];
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.infisical_postgres}" ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."infisical" = {
    serverName = "infisical.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.infisical}:8080";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
      '';
    };
  };
}
