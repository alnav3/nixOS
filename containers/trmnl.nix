{ lib, pkgs, ... }:

let
  myContainerIPs = {
    trmnl = "172.42.0.45";
  };
in
{
  virtualisation.oci-containers.containers = {
    trmnl = {
      image = "ghcr.io/usetrmnl/byos_laravel:latest";
      environment = {
        #APP_KEY = "";  # Uncomment and set this value if needed
        PHP_OPCACHE_ENABLE = "1";
        TRMNL_PROXY_REFRESH_MINUTES = "15";
        DB_DATABASE = "database/storage/database.sqlite";
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.trmnl}" ];
      volumes = [
        "/var/containers-data/trmnl/database:/var/www/html/database/storage"
        "/var/containers-data/trmnl/storage:/var/www/html/storage/app/public/images/generated"
      ];
      ports = [ ];
    };
  };

  containers = {
    nginx-internal.config.services.nginx.virtualHosts."trmnl.home" = {
      serverName = "trmnl.home";
      listen = [{ addr = "10.71.71.75"; port = 80; }];
      locations."/" = {
        proxyPass = "http://${myContainerIPs.trmnl}:8080";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
    nginx-external.config.services.nginx.virtualHosts."trmnl.alnav.dev" = {
      forceSSL = true;
      useACMEHost = "alnav.dev";
      serverName = "trmnl.alnav.dev";
      listen = [
        { addr = "10.71.71.193"; port = 80; }
        { addr = "10.71.71.193"; port = 443; ssl = true; }
      ];
      locations."/" = {
        proxyPass = "http://${myContainerIPs.trmnl}:8080";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
