{ lib, config, ... }:

let
  myContainerIPs = {
    dokploy = "172.42.0.26";
    dokploy-postgres = "172.42.0.27";
    dokploy-redis = "172.42.0.28";
  };
in
{
  networking.firewall.allowedTCPPorts = [ 3000 ];
  sops.secrets."dokploy.env" = { };

  virtualisation.oci-containers.containers = {
    dokploy-postgres = {
      image = "postgres:15-alpine";
      environmentFiles = [ "/run/secrets/dokploy.env" ];
      extraOptions = [
        "--net" "custom-net"
        "--ip" "${myContainerIPs.dokploy-postgres}"
        "--name" "dokploy-postgres"
      ];
      volumes = [
        "/var/lib/dokploy-postgres:/var/lib/postgresql/data"
      ];
    };

    dokploy-redis = {
      image = "redis:7.2-alpine";
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.dokploy-redis}" ];
      volumes = [
        "/var/containers-data/dokploy/redis:/data"
      ];
      cmd = [ "redis-server" "--appendonly" "yes" ];
    };

    dokploy = {
      image = "dokploy/dokploy:latest";
      environmentFiles = [ "/run/secrets/dokploy.env" ];
      extraOptions = [
        "--net" "custom-net"
        "--ip" "${myContainerIPs.dokploy}"
        "--name" "dokploy"
      ];
      ports = [
        "3000:3000"
      ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock:ro"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.dokploy.rule" = "Host(`dokploy.split.home`)";
        "traefik.http.routers.dokploy.service" = "dokploy";
        "traefik.http.services.dokploy.loadbalancer.server.port" = "3000";
      };
      dependsOn = [ "dokploy-postgres" "dokploy-redis" ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."dokploy.home" = {
    serverName = "dokploy.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.dokploy}:3000";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
