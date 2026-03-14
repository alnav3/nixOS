{ lib, pkgs, ... }:

{
  fileSystems."/mnt/gamesbackup" = {
    device = "//10.71.71.19/GamesBackup";
    fsType = "cifs";
    options = [
      "credentials=/run/secrets/smb-things-secrets"
      "uid=1000"
      "gid=100"
      "file_mode=0777"
      "dir_mode=0777"
      "x-systemd.idle-timeout=60"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
      "_netdev"
      "vers=3.0"
    ];
  };

  virtualisation.oci-containers.containers = {
    syncthing = {
      image = "syncthing/syncthing:latest";
      environment = {
        TZ = "Etc/UTC";
        PUID = "1000";
        PGID = "100";
      };
      extraOptions = [ "--network" "host" ];
      volumes = [
        "/var/containers-data/syncthing:/config"
        "/mnt/gamesbackup/syncthing-data:/data"
      ];
    };
  };

  systemd.services.docker-syncthing = {
    wantedBy = [ "multi-user.target" ];
    after = [ "mnt-gamesbackup.mount" ];
    bindsTo = [ "mnt-gamesbackup.mount" ];
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."syncthing.home" = {
    serverName = "syncthing.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://127.0.0.1:8384";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
