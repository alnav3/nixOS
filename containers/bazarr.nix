{
  containers.bazarr = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "172.69.0.1";
    localAddress = "172.69.0.34";

    config = { pkgs, lib, ... }: {

      services.bazarr = {
        enable = true;
        openFirewall = true;
      };

      networking.firewall.allowedTCPPorts = [ 6767 ]; # Bazarr UI port (custom)
      networking.useHostResolvConf = lib.mkForce false;
      services.resolved.enable = true;
      environment.systemPackages = with pkgs; [ cifs-utils ];

      system.stateVersion = "25.11";
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."bazarr.home" = {
    serverName = "bazarr.home";
    listen = [{ addr = "10.71.71.13"; port = 80; }];
    locations."/" = {
      proxyPass = "http://172.69.0.34:6767";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
  networking.extraHosts = "10.71.71.13 bazarr.home";
}

