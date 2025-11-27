{
  containers.pihole = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "172.69.0.1";
    localAddress = "172.69.0.50";

    config = { pkgs, lib, ... }: {
      # Install Pi-hole via Docker since NixOS doesn't have a native Pi-hole service
      virtualisation.docker.enable = true;
      virtualisation.oci-containers = {
        backend = "docker";
        containers.pihole = {
          image = "pihole/pihole:latest";
          autoStart = true;
          
          ports = [
            "53:53/tcp"   # DNS TCP
            "53:53/udp"   # DNS UDP
            "80:80/tcp"   # Web interface
          ];
          
          environment = {
            TZ = "Europe/London";
            FTLCONF_webserver_api_password = "correct horse battery staple";
            FTLCONF_dns_listeningMode = "ALL";
          };
          
          volumes = [
            "/var/lib/pihole/etc-pihole:/etc/pihole"
            "/var/lib/pihole/etc-dnsmasq.d:/etc/dnsmasq.d"
          ];
          
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--cap-add=SYS_TIME"
            "--cap-add=SYS_NICE"
            "--restart=unless-stopped"
          ];
        };
      };

      # Create persistent directories
      system.activationScripts.pihole-dirs = ''
        mkdir -p /var/lib/pihole/etc-pihole
        mkdir -p /var/lib/pihole/etc-dnsmasq.d
        chown -R 1000:1000 /var/lib/pihole
      '';

      networking.firewall.allowedTCPPorts = [ 53 80 ];
      networking.firewall.allowedUDPPorts = [ 53 ];
      networking.useHostResolvConf = lib.mkForce false;
      services.resolved.enable = true;

      system.stateVersion = "25.11";
    };
  };

  # Configure internal nginx proxy for Pi-hole web interface
  containers.nginx-internal.config.services.nginx.virtualHosts."pihole.home" = {
    serverName = "pihole.home";
    listen = [{ addr = "10.71.71.14"; port = 80; }];
    locations."/" = {
      proxyPass = "http://172.69.0.50:80";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
  
  networking.extraHosts = "10.71.71.14 pihole.home";
}