{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.deemix;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.deemix = {
    enable = lib.mkEnableOption "Deemix music downloader";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 36;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 6595;
      description = "Internal port for Deemix";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "deemix.home";
        description = "Internal domain name";
      };
      
      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "External domain name (enables external access)";
      };
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/deemix";
      description = "Directory for Deemix configuration";
    };
    
    musicDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media/media/Music";
      description = "Directory for music files";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.oci-containers.containers.deemix = {
        image = "registry.gitlab.com/bockiii/deemix-docker:latest";
        environment = clib.helpers.mkEnv ({
          PUID = "994";
          PGID = "104";
          UMASK_SET = "022";
        } // cfg.environment);
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
        ];
        volumes = [
          "${cfg.dataDir}:/config"
          "${clib.defaults.paths.downloadsDir}:/downloads"
          "${cfg.musicDir}:/music"
        ];
        ports = [];
      };
    }
    
    # Internal nginx proxy with WebSocket support
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.domain.internal;
          targetIP = containerIP;
          targetPort = cfg.port;
          extraConfig = ''
            ${clib.nginx.webSocketHeaders}
            proxy_read_timeout 86400;
          '';
        };
    })
    
    # External nginx proxy
    (lib.mkIf (cfg.domain.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.domain.external}" = 
        clib.nginx.mkExternalProxy {
          domain = cfg.domain.external;
          targetIP = containerIP;
          targetPort = cfg.port;
          extraConfig = ''
            ${clib.nginx.webSocketHeaders}
            proxy_read_timeout 86400;
          '';
        };
    })
  ]);
}
