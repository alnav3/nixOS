{ lib, pkgs, config, ... }:

let
  myContainerIPs = {
    ntfy = "172.42.0.38";
  };
in
{
  virtualisation.oci-containers.containers = {
    ntfy = {
      image = "binwiederhier/ntfy:latest";
      cmd = [ "serve" ];
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Etc/UTC";
      };
      volumes = [
        "/var/containers-data/ntfy/cache:/var/cache/ntfy"
        "/var/containers-data/ntfy/etc:/etc/ntfy"
      ];
      extraOptions = [
        "--net" "custom-net"
        "--ip" "${myContainerIPs.ntfy}"
      ];
    };
  };

  # Create data directories
  systemd.tmpfiles.rules = [
    "d /var/containers-data/ntfy 0755 root root -"
    "d /var/containers-data/ntfy/cache 0755 root root -"
    "d /var/containers-data/ntfy/etc 0755 root root -"
  ];

  # Create basic ntfy config
  environment.etc."ntfy/server.yml".text = ''
    base-url: "https://ntfy.alnav.dev"
    listen: ":80"
    cache-file: "/var/cache/ntfy/cache.db"
    auth-default-access: "read-write"
    behind-proxy: true
  '';

  containers = {
    nginx-external.config.services.nginx.virtualHosts."ntfy.alnav.dev" = {
      forceSSL = true;
      useACMEHost = "alnav.dev";
      serverName = "ntfy.alnav.dev";
      listen = [
        { addr = "10.71.71.193"; port = 80; }
        { addr = "10.71.71.193"; port = 443; ssl = true; }
      ];
      locations."/" = {
        proxyPass = "http://${myContainerIPs.ntfy}:80";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;

          # WebSocket support for ntfy
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
      };
    };
  };
}
