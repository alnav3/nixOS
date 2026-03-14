{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.metube;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.metube = {
    enable = lib.mkEnableOption "MeTube YouTube downloader";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 39;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Internal port for MeTube";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "youtube.home";
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
      default = "${clib.defaults.paths.dataDir}/metube";
      description = "Directory for MeTube state";
    };
    
    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media/media/Youtube";
      description = "Directory for downloaded videos";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.oci-containers.containers.metube = {
        image = "ghcr.io/alexta69/metube:latest";
        environment = clib.helpers.mkEnv ({
          UID = "994";
          GID = "104";
          UMASK = "022";
          DOWNLOAD_DIR = "/downloads";
          STATE_DIR = "/.metube";
          TEMP_DIR = "/downloads";
          DEFAULT_THEME = "auto";
        } // cfg.environment);
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
        ];
        volumes = [
          "${cfg.downloadDir}:/downloads"
          "${cfg.dataDir}:/.metube"
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
