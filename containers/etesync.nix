{ lib, pkgs, ... }:

let
  myContainerIPs = {
    etesync = "172.42.0.44";
  };
in
{
  # Ensure data directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/containers-data/etesync 0755 373 373 -"
  ];
  virtualisation.oci-containers.containers = {
    etesync = {
      image = "victorrds/etesync:latest";
      environment = {
        TZ = "Etc/UTC";
        ALLOWED_HOSTS = "etesync.home,172.42.0.44,localhost,127.0.0.1";
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.etesync}" ];
      volumes = [
        "/var/containers-data/etesync:/data"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."etesync.home" = {
    serverName = "etesync.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.etesync}:3735";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
