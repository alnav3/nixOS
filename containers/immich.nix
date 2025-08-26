{ lib, pkgs, config, ... }:

let
  myContainerIPs = {
    immich = "172.42.0.23";
    postgres = "172.42.0.24";
    redis = "172.42.0.25";
  };
in
{
    sops.secrets."smb-photos-secrets" = { };
    sops.secrets."immich.env" = { };

    fileSystems."/mnt/photos" = {
        device = "//10.71.71.19/photos";
        fsType = "cifs";
        options = [
            "credentials=/run/secrets/smb-photos-secrets"
                "uid=1234"
                "gid=1235"
                "file_mode=0700"
                "dir_mode=0700"
                "x-systemd.idle-timeout=60"
                "x-systemd.device-timeout=5s"
                "x-systemd.mount-timeout=5s"
                "_netdev"
                "vers=3.0"
        ];
    };

    virtualisation.oci-containers.containers = {

        immich_server = {
            environment = {
                PUID = "1234";
                PGID = "1235";
                TZ = "Etc/UTC";
            };
            environmentFiles = [ "/run/secrets/immich.env" ];
            image = "ghcr.io/immich-app/immich-server:release";
            volumes = [
                "/mnt/photos/immich:/data"                 # maps UPLOAD_LOCATION -> /data in container
                "/etc/localtime:/etc/localtime:ro"
            ];
            extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.immich}" ];
            # TODO: delete this port
            ports = [ "2283:2283" ];
            dependsOn = [ "redis" "immich_postgres" ];
            serviceName = "immich_server";
        };

        immich_machine_learning = {
            image = "ghcr.io/immich-app/immich-machine-learning:release";
            volumes = [
                "/var/containers-data/immich/model-cache:/cache"
            ];
            extraOptions = [ "--net" "custom-net" ];
            # TODO: host toolkit and extra device flags here for gpu
        };

        redis = {
            image = "docker.io/valkey/valkey:8-bookworm@sha256:facc1d2c3462975c34e10fccb167bfa92b0e0dbd992fc282c29a61c3243afb11";
            extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.redis}" ];
            ports = [];
        };

        immich_postgres = {
            image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";
            environmentFiles = [ "/run/secrets/immich.env" ]; # expects POSTGRES_* etc or DB_* depending on image
            volumes = [
                "/var/containers-data/immich/postgres:/var/lib/postgresql/data"
            ];
            extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.postgres}" ];
        };
    };
    containers.nginx-internal.config.services.nginx.virtualHosts."immich" = {
      serverName = "photos.home";
      listen = [{ addr = "10.71.71.75"; port = 80; }];
      locations."/" = {
          proxyPass = "http://${myContainerIPs.immich}:2283";
          extraConfig = ''
              client_max_body_size 10G;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
          '';
      };
    };
}

