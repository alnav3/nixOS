{

    sops.secrets."cloudflare.env" = { };
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
        nginx-external = {
            bindMounts = {
                "/run/secrets/cloudflare.env" = {
                    hostPath = "/run/secrets/cloudflare.env";
                    isReadOnly = false;
                };
            };

            autoStart = true;
            privateNetwork = false;
            config = { config, pkgs, lib, ... }: {
                security.acme.certs."alnav.dev" = {
                    domain = "*.alnav.dev";
                    dnsProvider = "cloudflare";
                    credentialsFile = "/run/secrets/cloudflare.env";
                    group = config.services.nginx.group;
                };
                security.acme = {
                    acceptTerms = true;
                    defaults.email = "nginx@apps.alnav.dev";
                };
                services.nginx = {
                    enable = true;
                };
                networking.firewall.allowedTCPPorts = [ 80 443 ];
                system.stateVersion = "25.11";
            };
        };
    };

}
