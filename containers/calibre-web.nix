{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.calibre-web;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.calibre-web = {
    enable = lib.mkEnableOption "Calibre-Web ebook library manager";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 22;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = "Internal port for Calibre-Web (uses 443 internally)";
    };
    
    hostPort = lib.mkOption {
      type = lib.types.port;
      default = 8083;
      description = "Host port mapping";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "books.home";
        description = "Internal domain name";
      };
      
      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "books.alnav.dev";
        description = "External domain name (enables external access)";
      };
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/calibre";
      description = "Directory for Calibre-Web configuration";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.oci-containers.containers.calibre = {
        image = "lscr.io/linuxserver/calibre-web:latest";
        environment = clib.helpers.mkEnv ({
          PUID = "994";
          PGID = "104";
        } // cfg.environment);
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
        ];
        volumes = [
          "${cfg.dataDir}/config:/config"
          "${cfg.dataDir}/books:/books"
        ];
        ports = [ "${toString cfg.hostPort}:${toString cfg.port}" ];
      };
    }
    
    # Internal nginx proxy
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.domain.internal;
          targetIP = containerIP;
          targetPort = cfg.port;
          clientMaxBodySize = "10G";
        };
    })
    
    # External nginx proxy with custom buffer configuration
    (lib.mkIf (cfg.domain.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.domain.external}" = 
        clib.nginx.mkExternalProxy {
          domain = cfg.domain.external;
          targetIP = containerIP;
          targetPort = cfg.port;
          clientMaxBodySize = "10G";
          extraConfig = ''
            proxy_busy_buffers_size   1024k;
            proxy_buffers   4 512k;
            proxy_buffer_size   1024k;
          '';
        };
    })
  ]);
}
