{ lib, config, ... }:

let
  cfg = config.myContainers;

  defaultNetwork = "custom-net";
  baseIP = "172.42.0.";

  mkContainer = name: cCfg: {
    # Build each container under its name
    "${name}" = {
      # Fallback image if none provided
      image = if cCfg.image == null then
        "lscr.io/linuxserver/${name}:latest"
      else cCfg.image;

      # Ensure environment is always an attrset
      environment = if cCfg.environment == null then {
        PUID = "1000";
        PGID = "1000";
        TZ   = "Etc/UTC";
      } else cCfg.environment;

      # Network options
      extraOptions = [
        "--net" defaultNetwork
        "--ip"  "${baseIP}${toString cCfg.ipSuffix}"
      ] ++ (cCfg.extraOptions or []);

      # Volumes and ports
      volumes = cCfg.volumes or [];
      ports   = cCfg.ports or [];
    };
  };

  # Filter and build only enabled containers
  enabledContainers = lib.filterAttrs (_: c: c.enable or false) cfg;
  containerConfigs  = lib.mapAttrs mkContainer enabledContainers;

  # Construct /etc/hosts entries
  hostsEntries = lib.concatStrings (
    lib.mapAttrsToList (name: c:
      "${baseIP}${toString c.ipSuffix} ${name}\n"
    ) enabledContainers
  );


in
{
  # Option definitions under myContainers namespace
  options.myContainers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "Enable this container";
        ipSuffix = lib.mkOption {
          type = lib.types.int;
          description = "Last segment of the container's IP (e.g., 11 for 172.42.0.11)";
        };
        image = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Docker image override (fallback to lscr.io/linuxserver/<container>:latest)";
        };
        environment = lib.mkOption {
          type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
          default = null;
          description = "Environment variables (PUID, PGID, TZ by default)";
        };
        extraOptions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Extra Docker run options";
        };
        volumes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Volume bindings";
        };
        ports = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Port mappings";
        };
      };
    });
    default     = {};
    description = "Definitions for custom OCI containers";
  };

  # Set module config: define containers and /etc/hosts
  config = {
    virtualisation.oci-containers.containers =
      lib.mkMerge (lib.attrValues containerConfigs);

    networking.extraHosts = hostsEntries;
  };
}

