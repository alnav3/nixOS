{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.transmission;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.transmission = {
    enable = lib.mkEnableOption "Transmission BitTorrent client";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 11;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 9091;
      description = "Internal web UI port";
    };
    
    peerPort = lib.mkOption {
      type = lib.types.port;
      default = 51413;
      description = "Peer communication port";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "torrent.home";
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
      default = "${clib.defaults.paths.dataDir}/transmission";
      description = "Directory for Transmission configuration";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.oci-containers.containers.transmission = {
        image = "lscr.io/linuxserver/transmission:latest";
        environment = clib.helpers.mkEnv ({
          PUID = "1000";
          PGID = "1000";
        } // cfg.environment);
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
        ];
        volumes = [
          "${cfg.dataDir}/config:/config"
          "${clib.defaults.paths.downloadsDir}:/downloads"
          "${cfg.dataDir}/watch:/watch"
        ];
        ports = [
          "${toString cfg.peerPort}:${toString cfg.peerPort}/tcp"
          "${toString cfg.peerPort}:${toString cfg.peerPort}/udp"
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
