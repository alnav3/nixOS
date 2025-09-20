{ lib, config, ... }:

let
  traefikIP = "172.42.0.100";
in
{
  networking.firewall.allowedTCPPorts = [ 80 443 8080 ];
  
  # Create traefik config directory
  systemd.tmpfiles.rules = [
    "d /var/lib/traefik 0755 root root -"
    "f /var/lib/traefik/traefik.yml 0644 root root -"
  ];

  # Traefik configuration file
  environment.etc."traefik/traefik.yml".text = ''
    api:
      dashboard: true
      insecure: true

    entryPoints:
      web:
        address: ":80"
      websecure:
        address: ":443"

    providers:
      docker:
        endpoint: "unix:///var/run/docker.sock"
        exposedByDefault: false
        network: "custom-net"

    certificatesResolvers:
      letsencrypt:
        acme:
          email: your-email@domain.com
          storage: /data/acme.json
          httpChallenge:
            entryPoint: web

    log:
      level: INFO
  '';

  virtualisation.oci-containers.containers = {
    traefik = {
      image = "traefik:v3.0";
      extraOptions = [
        "--net" "custom-net"
        "--ip" "${traefikIP}"
        "--name" "traefik"
      ];
      ports = [
        "80:80"
        "443:443"
        "8080:8080"  # Dashboard
      ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock:ro"
        "/etc/traefik:/etc/traefik:ro"
        "/var/lib/traefik:/data"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.dashboard.rule" = "Host(`traefik.split.home`)";
        "traefik.http.routers.dashboard.service" = "api@internal";
      };
    };
  };
}