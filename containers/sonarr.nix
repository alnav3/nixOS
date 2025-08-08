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
    users.users.sonarr = {
        isSystemUser = true;
        group = "media";
        uid = 253;
    };

    containers.sonarr = {
        autoStart = true; # Optional, start on boot
        privateNetwork = true; # Isolated network, or false to share with host
        hostAddress = "172.69.0.1";
        localAddress = "172.69.0.31";
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

        config = { pkgs, lib, ... }: {
            users.groups.media = {};
            users.users.sonarr = {
                isSystemUser = true;
                group = "media";
                uid = 274;
            };
            services.sonarr = {
                enable = true;
                user = "sonarr";
                group = "media";
                openFirewall = true;
            };
            networking.firewall.allowedTCPPorts = [ 8989 ]; # Open Sonarr port
                networking.useHostResolvConf = lib.mkForce false;
            services.resolved.enable = true;
            environment.systemPackages = with pkgs; [ cifs-utils ];

            system.stateVersion = "25.11";
        };
    };
    containers.nginx-internal.config.services.nginx.virtualHosts."sonarr.home" = {
        serverName = "sonarr.home";
        listen = [{ addr = "10.71.71.75"; port = 80; }];
        locations."/" = {
            proxyPass = "http://172.69.0.31:8989";
            extraConfig = ''
                proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            '';
        };
    };

}

