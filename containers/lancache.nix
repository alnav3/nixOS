{ lib, pkgs, ... }:

let
  myContainerIPs = {
    lancache-dns = "10.0.39.60";
    lancache-monolithic = "10.0.39.61";
  };
in
{
  virtualisation.oci-containers.containers = {
    lancache-dns = {
      image = "lancachenet/lancache-dns:latest";
      environment = {
        USE_GENERIC_CACHE = "true";
        LANCACHE_IP = "${myContainerIPs.lancache-monolithic}";
        DNS_BIND_IP = "10.71.71.75";
        UPSTREAM_DNS = "10.71.71.1";
        TZ = "Asia/Tashkent";
      };
      extraOptions = [
        "--net" "lancache-net"
        "--ip" "${myContainerIPs.lancache-dns}"
      ];
      ports = [
        "53:53/udp"
        "53:53/tcp"
      ];
    };

    lancache-monolithic = {
      image = "lancachenet/monolithic:latest";
      environment = {
        USE_GENERIC_CACHE = "true";
        LANCACHE_IP = "${myContainerIPs.lancache-monolithic}";
        DNS_BIND_IP = "10.71.71.75";
        UPSTREAM_DNS = "10.71.71.1";
        CACHE_DISK_SIZE = "500g";
        MIN_FREE_DISK = "10g";
        CACHE_INDEX_SIZE = "125m";
        CACHE_MAX_AGE = "3650d";
        TZ = "Asia/Tashkent";
      };
      extraOptions = [
        "--net" "lancache-net"
        "--ip" "${myContainerIPs.lancache-monolithic}"
      ];
      volumes = [
        "/var/containers-data/lancache/cache:/data/cache"
        "/var/containers-data/lancache/logs:/data/logs"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."lancache.home" = {
    serverName = "lancache.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.lancache-monolithic}:80";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
