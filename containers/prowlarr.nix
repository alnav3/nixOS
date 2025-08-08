{
  containers.prowlarr = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "172.69.0.1";
    localAddress = "172.69.0.33";

    config = { lib, ... }: {
      users.groups.media = {};
      users.users.prowlarr = {
        isSystemUser = true;
        group = "media";
        uid = 275;
      };

      services.prowlarr = {
        enable = true;
        openFirewall = true;
      };

      networking.firewall.allowedTCPPorts = [ 9696 ]; # Prowlarr default port
      networking.useHostResolvConf = lib.mkForce false;
      services.resolved.enable = true;

      system.stateVersion = "25.11";
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."prowlarr.home" = {
    serverName = "prowlarr.home";
    listen = [{ addr = "10.71.71.13"; port = 80; }];
    locations."/" = {
      proxyPass = "http://172.69.0.33:9696";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
  networking.extraHosts = "10.71.71.13 prowlarr.home";
}

