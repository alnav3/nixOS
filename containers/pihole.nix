{ lib, pkgs, ... }:

let
  myContainerIPs = {
    pihole = "172.42.0.14";
  };
in
{
  virtualisation.oci-containers.containers = {
    pihole = {
      image = "pihole/pihole:latest";
      environment = {
        TZ = "Europe/London";
        FTLCONF_dns_listeningMode = "ALL";
      };
      extraOptions = [
        "--net" "custom-net"
        "--ip" "${myContainerIPs.pihole}"
        "--cap-add=NET_ADMIN"
      ];
      volumes = [
        "/var/containers-data/pihole/etc-pihole:/etc/pihole"
        "/var/containers-data/pihole/etc-dnsmasq.d:/etc/dnsmasq.d"
      ];
      ports = [
        "53:53/tcp"   # DNS TCP
        "53:53/udp"   # DNS UDP
      ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."pihole.home" = {
    serverName = "pihole.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.pihole}:80";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
