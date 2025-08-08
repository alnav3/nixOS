{
    containers = {
        nginx-internal = {
            autoStart = true;
            privateNetwork = false;
            config = { config, pkgs, ... }: {
                services.nginx = {
                    enable = true;
                    # Internal proxy configuration here
                    virtualHosts."internal.local" = {
                        serverName = "test.home";

                        listen = [{ addr = "10.71.71.75"; port = 80; }];
                        locations."/" = {
                            proxyPass = "http://172.69.0.31:8989";
                        };
                    };
                };
                networking.firewall.allowedTCPPorts = [ 80 ];
                system.stateVersion = "25.11";
            };
        };
        #nginx-external = {
        #    autoStart = true;
        #    privateNetwork = false;
        #    hostAddress = "10.71.71.13";  # Host's IP for this container's bridge
        #        localAddress = "10.71.71.77";  # Container's internal IP
        #        forwardPorts = [  # Forward host ports to container for ACME and access
        #        { containerPort = 80; hostPort = 80; protocol = "tcp"; }
        #    { containerPort = 443; hostPort = 443; protocol = "tcp"; }
        #        ];
        #        config = { config, pkgs, ... }: {
# ACME c#onfig moved here (top-level)
        #            security.acme = {
        #                acceptTerms = true;
        #                defaults.email = "your-email@example.com";  # Use a valid email
        #            };
        #            services.nginx = {
        #                enable = true;
# Extern#al proxy configuration here
        #                virtualHosts."external.example.com" = {
        #                    listen = [{ addr = "172.69.0.3"; port = 80; } { addr = "172.69.0.3"; port = 443; ssl = true; }];
# Enable# SSL/TLS and use as reverse proxy
        #                    forceSSL = true;
        #                    enableACME = true;  # Now works with top-level security.acme
        #                        locations."/" = {
        #                            proxyPass = "http://upstream-external-service:8080";  # Adjust to real upstream
        #                        };
        #                };
        #            };
        #            networking.firewall.allowedTCPPorts = [ 80 443 ];
        #        };
        #};
    };


}


