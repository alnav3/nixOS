{ lib, pkgs, ... }:

let
  myContainerIPs = {
    searx = "172.42.0.21";
  };
in
{
  virtualisation.oci-containers.containers = {
    searx = {
      image = "searxng/searxng:latest";
      environment = {
        TZ = "Etc/UTC";
        # TODO: secret just for testing - change in the future
        SEARX_SECRET_KEY = "tcmaahDTQYAXpYPhOKfzK7UiZ/f5YguCrUWcU672rZI=";
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.searx}" ];
    };
  };

  containers = {
      nginx-internal.config.services.nginx.virtualHosts."search.home" = {
          serverName = "search.home";
          listen = [{ addr = "10.71.71.75"; port = 80; }];
          locations."/" = {
              proxyPass = "http://${myContainerIPs.searx}:8080";
              extraConfig = ''
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
              '';
          };
      };
      nginx-external.config.services.nginx.virtualHosts."search.alnav.dev" = {
          forceSSL = true;
          useACMEHost = "alnav.dev";
          serverName = "search.alnav.dev";
          listen = [
              { addr = "10.71.71.193"; port = 80; }
              { addr = "10.71.71.193"; port = 443; ssl = true; }
          ];
          locations."/" = {
              proxyPass = "http://${myContainerIPs.searx}:8080";
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

