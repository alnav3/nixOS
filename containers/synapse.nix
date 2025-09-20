{ lib, pkgs, config, ... }:

let
  myContainerIPs = {
    synapse = "172.42.0.40";
  };
in
{
  # Create the data directory
  systemd.tmpfiles.rules = [
    "d /var/containers-data/synapse 0755 root root -"
    "d /var/containers-data/synapse/data 0755 root root -"
  ];

  virtualisation.oci-containers.containers = {
    synapse = {
      image = "matrixdotorg/synapse:latest";
      volumes = [
        "synapse-data:/data"
        "/var/containers-data/mautrix-whatsapp:/mautrix-whatsapp:ro"
      ];
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.synapse}" ];
    };
  };

  containers = {
      nginx-internal.config.services.nginx.virtualHosts."synapse" = {
          serverName = "matrix.home";
          listen = [{ addr = "10.71.71.75"; port = 80; }];
          locations."/" = {
              proxyPass = "http://${myContainerIPs.synapse}:8008";
              extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              '';
          };
      };
      nginx-external.config.services.nginx.virtualHosts."matrix.alnav.dev" = {
          forceSSL = true;
          useACMEHost = "alnav.dev";
          serverName = "matrix.alnav.dev";
          listen = [
          { addr = "10.71.71.193"; port = 80; }
          { addr = "10.71.71.193"; port = 443; ssl = true; }
          ];
          locations."/" = {
              proxyPass = "http://${myContainerIPs.synapse}:8008";
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
