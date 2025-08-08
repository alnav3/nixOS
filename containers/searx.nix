{
  containers.searx = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = "172.69.0.1";
      localAddress = "172.69.0.22";
      config = { lib, ... }: {
          services.searx = {
              enable = true;
              settings.server.bind_address = "0.0.0.0";
              settings.server.port = 8080;
              settings.server.secret_key = "tcmaahDTQYAXpYPhOKfzK7UiZ/f5YguCrUWcU672rZI="; #temp testing
          };

          networking.firewall.allowedTCPPorts = [ 8080 ];

          networking.useHostResolvConf = lib.mkForce false;
          services.resolved.enable = true;
      };
  };
  containers.nginx-internal.config.services.nginx.virtualHosts."search.home" = {
      serverName = "search.home";
      listen = [{ addr = "10.71.71.75"; port = 80; }];
      locations."/" = {
          proxyPass = "http://172.69.0.22:8080";
          extraConfig = ''
              proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          '';
      };
  };
}

