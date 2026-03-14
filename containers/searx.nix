{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.searx;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.searx = {
    enable = lib.mkEnableOption "SearXNG metasearch engine";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 21;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Internal port for SearXNG";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "search.home";
        description = "Internal domain name";
      };
      
      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "search.alnav.dev";
        description = "External domain name (enables external access)";
      };
    };
    
    secretKey = lib.mkOption {
      type = lib.types.str;
      default = "tcmaahDTQYAXpYPhOKfzK7UiZ/f5YguCrUWcU672rZI=";
      description = "Secret key for SearXNG (should be changed)";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.oci-containers.containers.searx = {
        image = "searxng/searxng:latest";
        environment = {
          TZ = clib.defaults.environment.TZ;
          SEARX_SECRET_KEY = cfg.secretKey;
        } // cfg.environment;
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
        ];
      };
    }
    
    # Internal nginx proxy
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.domain.internal;
          targetIP = containerIP;
          targetPort = cfg.port;
        };
    })
    
    # External nginx proxy
    (lib.mkIf (cfg.domain.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.domain.external}" = 
        clib.nginx.mkExternalProxy {
          domain = cfg.domain.external;
          targetIP = containerIP;
          targetPort = cfg.port;
        };
    })
  ]);
}
