{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.kasm;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.kasm = {
    enable = lib.mkEnableOption "Kasm Workspaces browser isolation";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 47;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Internal HTTP port for Kasm";
    };
    
    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 4443;
      description = "HTTPS port for Kasm";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "kasm.home";
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
      default = "${clib.defaults.paths.dataDir}/kasm";
      description = "Directory for Kasm data";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.oci-containers.containers.kasm = {
        image = "lscr.io/linuxserver/kasm:latest";
        environment = {
          TZ = clib.defaults.environment.TZ;
          KASM_PORT = toString cfg.httpsPort;
          DOCKER_MTU = "1500";
        } // cfg.environment;
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
          "--privileged"
        ];
        volumes = [
          "${cfg.dataDir}:/opt"
          "${cfg.dataDir}/profiles:/profiles"
          "/dev/input:/dev/input"
          "/run/udev/data:/run/udev/data"
        ];
        ports = [
          "${toString cfg.port}:${toString cfg.port}"
          "${toString cfg.httpsPort}:${toString cfg.httpsPort}"
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
