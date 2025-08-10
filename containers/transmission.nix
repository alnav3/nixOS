{ lib, ... }:
let
  myContainerIPs = {
    transmission = "172.42.0.11";
  };
in
{
  virtualisation.oci-containers.containers = {
    transmission = {
      image = "lscr.io/linuxserver/transmission:latest";
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Etc/UTC";
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.transmission}" ];
      volumes = [
        "/var/containers-data/transmission/config:/config"
        "/mnt/things:/downloads"
        "/var/containers-data/transmission/watch:/watch"
      ];
      ports = [ "51413:51413/tcp" "51413:51413/udp" ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."transmission" = {
      serverName = "torrent.home";
      listen = [{ addr = "10.71.71.75"; port = 80; }];
      locations."/" = {
          proxyPass = "http://${myContainerIPs.transmission}:9091";
          extraConfig = ''
              proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          '';
      };
    };


}

