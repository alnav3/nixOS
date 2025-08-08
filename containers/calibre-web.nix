{ config, lib, pkgs, ... }:

let
  nginxInternalAddr = "10.71.71.13";  # Address from your nginx-internal listen config
  calibreIp = "172.69.0.5";  # Calibre container's localAddress
in
{
  options = {
    services.calibre-web = {
      proxyEnable = lib.mkEnableOption "Enable nginx-internal reverse proxy for calibre-web";
    };
  };

  config = lib.mkIf config.services.calibre-web.proxyEnable {
    containers.calibreweb = {
      autoStart = true;
      ephemeral = false;
      privateNetwork = true;
      hostAddress = "172.69.0.1";  # Host side of the bridge
      localAddress = calibreIp;
      config = {
        services.calibre-web.enable = true;
        services.calibre-web.group = "media";
        services.calibre-web.listen.ip = "0.0.0.0";
        services.calibre-web.listen.port = 8083;
        #services.calibre-web.options.calibreLibrary = "/path/to/calibre/library";  # Update to your actual path
        services.calibre-web.options.enableBookUploading = true;
        services.calibre-web.options.enableBookConversion = true;

        users.users.calibre = {
          isSystemUser = true;
          group = "media";
          extraGroups = [ "network" ];
        };

        users.groups.media = {
          gid = 999;
        };

        networking.firewall.allowedTCPPorts = [ 8083 ];
      };
    };

    # Extend your existing nginx-internal container with the proxy config
    containers.nginx-internal.config.services.nginx.virtualHosts."books.home" = {
      serverName = "books.home";
      listen = [{ addr = nginxInternalAddr; port = 80; }];
      locations."/" = {
        proxyPass = "http://${calibreIp}:8083";
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

