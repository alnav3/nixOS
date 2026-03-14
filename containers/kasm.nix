{ lib, pkgs, ... }:

let
  myContainerIPs = {
    kasm = "172.42.0.47";
  };
in
{
  virtualisation.oci-containers.containers = {
    kasm = {
      image = "lscr.io/linuxserver/kasm:latest";
      environment = {
        TZ = "Etc/UTC";
        KASM_PORT = "4443";
        DOCKER_MTU = "1500";
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.kasm}" "--privileged" ];
      volumes = [
        "/var/containers-data/kasm:/opt"
        "/var/containers-data/kasm/profiles:/profiles"
        "/dev/input:/dev/input"
        "/run/udev/data:/run/udev/data"
      ];
      ports = [
        "3000:3000"
        "4443:4443"
      ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."kasm.home" = {
    serverName = "kasm.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.kasm}:3000";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
