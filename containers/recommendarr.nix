{ lib, pkgs, ... }:

let
  myContainerIPs = {
    recommendarr = "172.42.0.36";
  };
in
{
  virtualisation.oci-containers.containers = {
    recommendarr = {
      image = "tannermiddleton/recommendarr:latest";
      environment = {
        TZ = "Etc/UTC";
        PUID = "994";
        PGID = "104";
      };
      extraOptions = [ 
        "--net" "custom-net" 
        "--ip" "${myContainerIPs.recommendarr}"
      ];
      volumes = [
        "/var/containers-data/recommendarr:/app/server/data"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."recommendarr.home" = {
    serverName = "recommendarr.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.recommendarr}:3000";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}