{ lib, pkgs, ... }:

let
  myContainerIPs = {
    suggestarr = "172.42.0.37";
  };
in
{
  virtualisation.oci-containers.containers = {
    suggestarr = {
      image = "ciuse99/suggestarr:latest";
      environment = {
        TZ = "Etc/UTC";
        PUID = "994";
        PGID = "104";
        LOG_LEVEL = "info";
        SUGGESTARR_PORT = "5000";
      };
      extraOptions = [ 
        "--net" "custom-net" 
        "--ip" "${myContainerIPs.suggestarr}"
      ];
      volumes = [
        "/var/containers-data/suggestarr:/app/config/config_files"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."suggestarr.home" = {
    serverName = "suggestarr.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.suggestarr}:5000";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}