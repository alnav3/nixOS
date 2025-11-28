{ lib, pkgs, ... }:

let
  myContainerIPs = {
    calibre = "172.42.0.22";
  };
in
{
  virtualisation.oci-containers.containers = {
    calibre = {
      image = "lscr.io/linuxserver/calibre-web:latest";
      environment = {
        TZ  = "Etc/UTC";
        PUID = "994";
        PGID = "104";
        # Optional extras:
        # DOCKER_MODS = "linuxserver/mods:universal-calibre"; # optional: ebook conversion layer
        # OAUTHLIB_RELAX_TOKEN_SCOPE = "1";                  # optional for Google OAUTH
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.calibre}" ];
      volumes = [
        "/var/containers-data/calibre/config:/config"
        "/var/containers-data/calibre/books:/books"
      ];
      ports = [ "8083:443" ];
    };
  };

  containers = {
      nginx-internal.config.services.nginx.virtualHosts."books.home" = {
          serverName = "books.home";
          listen = [{ addr = "10.71.71.75"; port = 80; }];
          locations."/" = {
              proxyPass = "http://${myContainerIPs.calibre}:443";
              extraConfig = ''
                  proxy_set_header Host $host;
                  client_max_body_size 10G;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
              '';
          };
      };
      nginx-external.config.services.nginx.virtualHosts."books.alnav.dev" = {
          forceSSL = true;
          useACMEHost = "alnav.dev";
          serverName = "books.alnav.dev";
          listen = [
              { addr = "10.71.71.193"; port = 80; }
              { addr = "10.71.71.193"; port = 443; ssl = true; }
          ];
          locations."/" = {
              proxyPass = "http://${myContainerIPs.calibre}:443";
              extraConfig = ''
                  proxy_busy_buffers_size   1024k;
                  proxy_buffers   4 512k;
                  proxy_buffer_size   1024k;
                  proxy_set_header Host $host;
                  client_max_body_size 10G;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
              '';
          };
      };

  };
}

