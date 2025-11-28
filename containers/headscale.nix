{ lib, pkgs, ... }:

{
  # Ensure secrets are available for DuckDNS token
  #sops.secrets."duckdns-token" = { };

  # DuckDNS container to keep domain updated with current IP
  #containers.duckdns = {
  #  autoStart = true;
  #  privateNetwork = false;
  #  bindMounts = {
  #    "/run/secrets/duckdns-token" = {
  #      hostPath = "/run/secrets/duckdns-token";
  #      isReadOnly = true;
  #    };
  #  };
  #  config = { config, pkgs, lib, ... }: {
  #    systemd.services.duckdns = {
  #      description = "DuckDNS Dynamic DNS updater";
  #      after = [ "network.target" ];
  #      wantedBy = [ "multi-user.target" ];
  #      serviceConfig = {
  #        Type = "oneshot";
  #        ExecStart = "${pkgs.curl}/bin/curl -s \"https://www.duckdns.org/update?domains=alnav&token=$(cat /run/secrets/duckdns-token)&ip=\"";
  #        User = "nobody";
  #        Group = "nogroup";
  #      };
  #    };
  #
  #    systemd.timers.duckdns = {
  #      description = "Update DuckDNS every 5 minutes";
  #      wantedBy = [ "timers.target" ];
  #      timerConfig = {
  #        OnBootSec = "5min";
  #        OnUnitActiveSec = "5min";
  #        Unit = "duckdns.service";
  #      };
  #    };
  #
  #    system.stateVersion = "25.11";
  #  };
  #};

  # Add ACME certificate for alnav.duckdns.org using HTTP validation (much simpler!)
  #containers.nginx-external.config.security.acme.certs."alnav.duckdns.org" = {
  #  domain = "alnav.duckdns.org";
  #  # Use HTTP validation instead of DNS - much simpler!
  #  webroot = "/var/lib/acme/acme-challenge";
  #  group = "nginx";
  #};

  ## Ensure the ACME webroot directory structure exists
  #containers.nginx-external.config.systemd.tmpfiles.rules = [
  #  "d /var/lib/acme 0755 acme nginx"
  #  "d /var/lib/acme/.well-known 0755 acme nginx"
  #  "d /var/lib/acme/.well-known/acme-challenge 0755 acme nginx"
  #];

  ## Add virtual host to existing nginx-external container for external SSL access
  #containers.nginx-external.config.services.nginx.virtualHosts."alnav.duckdns.org" = {
  #  serverName = "alnav.duckdns.org";
  #  listen = [
  #    { addr = "0.0.0.0"; port = 443; ssl = true; }
  #    { addr = "0.0.0.0"; port = 80; }
  #  ];

  #  # Use ACME certificate
  #  useACMEHost = "alnav.duckdns.org";
  #  # DON'T use forceSSL - it breaks ACME challenge serving

  #  # Serve ACME challenges for HTTP validation (must be first/most specific)
  #  locations."/.well-known/acme-challenge" = {
  #    root = "/var/lib/acme";
  #  };

  #  # Route only /api path to headscale server (HTTPS only)
  #  locations."/api" = {
  #    proxyPass = "http://10.71.71.96:80";
  #    extraConfig = ''
  #      # Redirect HTTP to HTTPS for API calls
  #      if ($scheme = http) {
  #        return 301 https://$server_name$request_uri;
  #      }
  #      proxy_set_header Host $host;
  #      proxy_set_header X-Real-IP $remote_addr;
  #      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  #      proxy_set_header X-Forwarded-Proto $scheme;
  #    '';
  #  };

  #  # Redirect all other HTTP paths to HTTPS (except ACME challenges)
  #  locations."/" = {
  #    extraConfig = ''
  #      if ($scheme = http) {
  #        return 301 https://$server_name$request_uri;
  #      }
  #      return 404;
  #    '';
  #  };
  #};
}
