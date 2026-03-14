{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.bazarr;
  clib = import ./_lib { inherit lib; };
in
{
  options.services.mycontainers.bazarr = {
    enable = lib.mkEnableOption "Bazarr subtitle management";
    
    hostAddress = lib.mkOption {
      type = lib.types.str;
      default = "172.69.0.1";
      description = "Host address for system container";
    };
    
    localAddress = lib.mkOption {
      type = lib.types.str;
      default = "172.69.0.34";
      description = "Container local address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 6767;
      description = "Internal port for Bazarr";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "bazarr.home";
        description = "Internal domain name";
      };
      
      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "External domain name (enables external access)";
      };
    };
    
    internalProxyIP = lib.mkOption {
      type = lib.types.str;
      default = "10.71.71.13";
      description = "IP address for internal nginx proxy listener";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      containers.bazarr = {
        autoStart = true;
        privateNetwork = true;
        hostAddress = cfg.hostAddress;
        localAddress = cfg.localAddress;
        
        config = { pkgs, lib, ... }: {
          services.bazarr = {
            enable = true;
            openFirewall = true;
          };
          
          networking.firewall.allowedTCPPorts = [ cfg.port ];
          networking.useHostResolvConf = lib.mkForce false;
          services.resolved.enable = true;
          environment.systemPackages = with pkgs; [ cifs-utils ];
          
          system.stateVersion = "25.11";
        };
      };
      
      networking.extraHosts = lib.mkIf (cfg.domain.internal != null) "${cfg.internalProxyIP} ${cfg.domain.internal}";
    }
    
    # Internal nginx proxy
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" = {
        serverName = cfg.domain.internal;
        listen = [{ addr = cfg.internalProxyIP; port = 80; }];
        locations."/" = {
          proxyPass = "http://${cfg.localAddress}:${toString cfg.port}";
          extraConfig = clib.nginx.standardProxyHeaders;
        };
      };
    })
    
    # External nginx proxy
    (lib.mkIf (cfg.domain.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.domain.external}" = 
        clib.nginx.mkExternalProxy {
          domain = cfg.domain.external;
          targetIP = cfg.localAddress;
          targetPort = cfg.port;
        };
    })
  ]);
}
