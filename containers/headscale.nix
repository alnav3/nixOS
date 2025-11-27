{ lib, pkgs, ... }:

{
  # Add ACME certificate for alnav.duckdns.org to nginx-external
  containers.nginx-external.config.security.acme.certs."alnav.duckdns.org" = {
    domain = "alnav.duckdns.org";
    dnsProvider = "cloudflare";
    credentialsFile = "/run/secrets/cloudflare.env";
    group = "nginx";
  };

  # Add virtual host to existing nginx-external container for external SSL access
  containers.nginx-external.config.services.nginx.virtualHosts."alnav.duckdns.org" = {
    serverName = "alnav.duckdns.org";
    listen = [
      { addr = "0.0.0.0"; port = 443; ssl = true; }
      { addr = "0.0.0.0"; port = 80; }
    ];

    # Use ACME certificate
    useACMEHost = "alnav.duckdns.org";
    forceSSL = true;

    # Route only /api path to headscale server
    locations."/api" = {
      proxyPass = "http://10.71.71.96:80";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };

    # Return 404 for all other paths
    locations."/" = {
      extraConfig = ''
        return 404;
      '';
    };
  };
}
