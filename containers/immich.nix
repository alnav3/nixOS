{
  containers.immich = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "172.69.0.1";
    localAddress = "172.69.0.41";


    config = { config, pkgs, lib, ... }: {
      services.postgresql.package = pkgs.postgresql_15;

        services.immich.enable = true;
        services.immich.port = 2283;
        services.immich.openFirewall = true;
        services.immich.environment = {
            IMMICH_HOST= lib.mkForce "0.0.0.0";
        };

        networking.firewall.allowedTCPPorts = [ 2283 ];
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;

        environment.systemPackages = with pkgs; [ cifs-utils ];

        system.stateVersion = "25.11";
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."immich.home" = {
    serverName = "immich.home";
    listen = [{ addr = "10.71.71.13"; port = 80; }];
    locations."/" = {
      proxyPass = "http://172.69.0.41:2283";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  networking.extraHosts = "10.71.71.13 immich.home";
}

