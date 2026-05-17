{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.koffan;
  clib = import ./_lib { inherit lib; };

  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.koffan = {
    enable = lib.mkEnableOption "Koffan shopping list";

    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 53;
      description = "Last octet of container IP address";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Internal port for Koffan";
    };

    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "shoplist.home";
        description = "Internal domain name";
      };

      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "shoplist.alnav.dev";
        description = "External domain name (enables external access)";
      };
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/koffan";
      description = "Directory for Koffan data";
    };

    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/koffan.env";
      description = "Path to secrets environment file";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      sops.secrets."koffan.env" = {};

      virtualisation.oci-containers.containers.koffan = {
        image = "ghcr.io/pansalut/koffan:latest";
        environment = clib.helpers.mkEnv cfg.environment;
        environmentFiles = [ cfg.secretsFile ];
        volumes = [
          "${cfg.dataDir}:/data"
        ];
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
        ];
      };

      systemd.tmpfiles.rules = clib.helpers.mkDataDirs [
        "koffan"
      ];
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
