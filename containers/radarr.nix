{
    sops.secrets."smb-things-secrets" = { };

    fileSystems."/mnt/things" = {
        device = "//10.71.71.19/things";
        fsType = "cifs";
        options = [
            "credentials=/run/secrets/smb-things-secrets"
                "uid=alnav"
                "x-systemd.automount"
                "noauto"
                "_netdev"
                "vers=3.0"
        ];
    };

    fileSystems."/mnt/media" = {
        device = "//10.71.71.19/media";
        fsType = "cifs";
        options = [
            "credentials=/run/secrets/smb-things-secrets"
                "uid=alnav"
                "x-systemd.automount"
                "noauto"
                "_netdev"
                "vers=3.0"
        ];
    };

    users.groups.media = {};
    users.users.radarr = {
        isSystemUser = true;
        group = "media";
        uid = 254;  # Incremented from Sonarr's 253 to avoid conflicts
    };

    containers.radarr = {
        autoStart = true; # Optional, start on boot
            privateNetwork = true; # Isolated network, or false to share with host
            hostAddress = "172.69.0.1";  # Using a different subnet to avoid potential conflicts with Sonarr
            localAddress = "172.69.0.32";
        bindMounts = {
            "/mnt/things" = {
                hostPath = "/mnt/things";
                isReadOnly = false;
            };
            "/mnt/media" = {
                hostPath = "/mnt/media";
                isReadOnly = false;
            };
        };

        config = { lib, ... }: {
            users.groups.media = {};
            users.users.radarr = {
                isSystemUser = true;
                group = "media";
            };
            services.radarr = {
                enable = true;
                user = "radarr";
                group = "media";
                openFirewall = true;
            };
            networking.firewall.allowedTCPPorts = [ 7878 ]; # Open Radarr port
            networking.useHostResolvConf = lib.mkForce false;
            services.resolved.enable = true;
        };
    };
    containers.nginx-internal.config.services.nginx.virtualHosts."radarr.home" = {
        serverName = "radarr.home";
        listen = [{ addr = "10.71.71.13"; port = 80; }];
        locations."/" = {
            proxyPass = "http://172.69.0.32:7878";
            extraConfig = ''
                proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            '';
        };
    };


}
