{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.slskd;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.slskd = {
    enable = lib.mkEnableOption "Slskd Soulseek client";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 41;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 5030;
      description = "Internal HTTP port for Slskd";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "slskd.home";
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
      default = "${clib.defaults.paths.dataDir}/slskd";
      description = "Directory for Slskd configuration";
    };
    
    downloadsDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.downloadsDir}/slskd";
      description = "Directory for downloads";
    };
    
    incompleteDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.downloadsDir}/slskd-incomplete";
      description = "Directory for incomplete downloads";
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
      virtualisation.oci-containers.containers.slskd = {
        image = "slskd/slskd:latest";
        environment = clib.helpers.mkEnv ({
          PUID = "1000";
          PGID = "1000";
          SLSKD_HTTP_PORT = toString cfg.port;
          SLSKD_HTTPS_PORT = "5031";
          SLSKD_REMOTE_CONFIGURATION = "true";
        } // cfg.environment);
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
        ];
        volumes = [
          "${cfg.dataDir}:/app"
          "${cfg.downloadsDir}:/slskd-downloads"
          "${cfg.incompleteDir}:/slskd-incomplete"
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
          extraConfig = clib.nginx.webSocketHeaders;
        };
    })
    
    # External nginx proxy
    (lib.mkIf (cfg.domain.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.domain.external}" = 
        clib.nginx.mkExternalProxy {
          domain = cfg.domain.external;
          targetIP = containerIP;
          targetPort = cfg.port;
          extraConfig = clib.nginx.webSocketHeaders;
        };
    })
  ]);
}
