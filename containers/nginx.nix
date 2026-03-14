{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.nginx;
in
{
  options.services.mycontainers.nginx = {
    enableInternal = lib.mkEnableOption "Enable internal nginx reverse proxy";
    enableExternal = lib.mkEnableOption "Enable external nginx reverse proxy with SSL";
    
    acme = {
      email = lib.mkOption {
        type = lib.types.str;
        default = "nginx@apps.alnav.dev";
        description = "Email for ACME certificate registration";
      };
      
      defaultDomain = lib.mkOption {
        type = lib.types.str;
        default = "alnav.dev";
        description = "Default domain for wildcard certificates";
      };
      
      dnsProvider = lib.mkOption {
        type = lib.types.str;
        default = "cloudflare";
        description = "DNS provider for ACME challenges";
      };
      
      credentialsFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/secrets/cloudflare.env";
        description = "Path to DNS provider credentials";
      };
    };
  };
  
  config = lib.mkMerge [
    (lib.mkIf cfg.enableInternal {
      containers.nginx-internal = {
        autoStart = true;
        privateNetwork = false;
        config = { config, pkgs, ... }: {
          services.nginx = {
            enable = true;
            # Virtual hosts are configured by individual container modules
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
    })
    
    (lib.mkIf cfg.enableExternal {
      sops.secrets."cloudflare.env" = {};
      
      containers.nginx-external = {
        bindMounts = {
          "${cfg.acme.credentialsFile}" = {
            hostPath = cfg.acme.credentialsFile;
            isReadOnly = false;
          };
        };
        
        autoStart = true;
        privateNetwork = false;
        config = { config, pkgs, lib, ... }: {
          security.acme.certs."${cfg.acme.defaultDomain}" = {
            domain = "*.${cfg.acme.defaultDomain}";
            dnsProvider = cfg.acme.dnsProvider;
            credentialsFile = cfg.acme.credentialsFile;
            group = config.services.nginx.group;
          };
          
          security.acme = {
            acceptTerms = true;
            defaults.email = cfg.acme.email;
          };
          
          services.nginx = {
            enable = true;
            # Virtual hosts are configured by individual container modules
          };
          
          networking.firewall.allowedTCPPorts = [ 80 443 ];
          system.stateVersion = "25.11";
        };
      };
    })
  ];
}
