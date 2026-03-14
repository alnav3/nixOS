{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.synapse;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.synapse = {
    enable = lib.mkEnableOption "Synapse Matrix homeserver";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 40;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 8008;
      description = "Internal port for Synapse";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "matrix.home";
        description = "Internal domain name";
      };
      
      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "matrix.alnav.dev";
        description = "External domain name (enables external access)";
      };
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/synapse";
      description = "Directory for Synapse data";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Create the data directory
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 root root -"
        "d ${cfg.dataDir}/data 0755 root root -"
      ];
      
      virtualisation.oci-containers.containers.synapse = {
        image = "matrixdotorg/synapse:latest";
        volumes = [
          "synapse-data:/data"
          "${clib.defaults.paths.dataDir}/mautrix-whatsapp:/mautrix-whatsapp:ro"
        ];
        environment = cfg.environment;
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
