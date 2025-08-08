{
    import = [
        ./../../containers/containers.nix
    ];
    myContainers = {
        transmission = {
            enable = true;
            ipSuffix = 11;
            volumes = [
                "/home/alnav/transmission/config:/config"
                "/home/alnav/transmission/downloads:/downloads"
                "/home/alnav/transmission/watch:/watch"
            ];
            ports = [ "51413:51413/tcp" "51413:51413/udp" ];
        };

        #n8n = {
        #    enable      = true;
        #    ipSuffix    = 12;
        #    image       = "docker.io/n8nio/n8n:1.83.2";
        #    environment = {
        #        N8N_HOST         = "n8n";
        #        N8N_PORT         = "5678";
        #        N8N_PROTOCOL     = "http";
        #        NODE_ENV         = "production";
        #        GENERIC_TIMEZONE = "Europe/Berlin";
        #        N8N_SECURE_COOKIE= "false";
        #    };
        #    volumes     = [ "n8n_data:/home/node/.n8n" ];
        #};
    };

    # test
    networking.nat.enable = true;
    networking.nat.internalInterfaces = [ "ve-*" ];
    networking.nat.externalInterface = "wlp1s0"; # modify once we actually use this
    containers.n8n = {
        autoStart = true;
        privateNetwork = true;
        hostAddress = "172.69.0.1";   # Host side of the veth pair
        localAddress = "172.69.0.2";  # Container's IP
        config = { config, pkgs, ... }:
        {
            services.n8n = {
                enable = true;
                openFirewall = true;  # Allows port access from the host if necessary
                settings = {
                    listen_address = "0.0.0.0";
                    port = 5678;
                    generic_timezone = "Europe/Berlin";
                    protocol = "http";
                };

                environment = { N8N_SECURE_COOKIE = "false"; N8N_HOST = "n8n"; };
            };
        };
    };


}
