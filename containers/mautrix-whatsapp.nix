{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.mautrix-whatsapp;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.mautrix-whatsapp = {
    enable = lib.mkEnableOption "Mautrix-WhatsApp bridge for Matrix";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 50;
      description = "Last octet of container IP address";
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/mautrix-whatsapp";
      description = "Directory for Mautrix-WhatsApp data";
    };
    
    encryption = {
      allow = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow encryption";
      };
      
      default = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable encryption by default";
      };
      
      require = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Require encryption";
      };
      
      verificationLevel = lib.mkOption {
        type = lib.types.str;
        default = "unverified";
        description = "Verification level for encryption";
      };
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.mautrix-whatsapp = {
      image = "dock.mau.dev/mautrix/whatsapp:latest";
      volumes = [
        "${cfg.dataDir}:/data"
      ];
      environment = {
        MAUTRIX_WHATSAPP_ENCRYPTION_ALLOW = lib.boolToString cfg.encryption.allow;
        MAUTRIX_WHATSAPP_ENCRYPTION_DEFAULT = lib.boolToString cfg.encryption.default;
        MAUTRIX_WHATSAPP_ENCRYPTION_REQUIRE = lib.boolToString cfg.encryption.require;
        MAUTRIX_WHATSAPP_ENCRYPTION_VERIFICATION_LEVELS_RECEIVE = cfg.encryption.verificationLevel;
        MAUTRIX_WHATSAPP_ENCRYPTION_VERIFICATION_LEVELS_SEND = cfg.encryption.verificationLevel;
        MAUTRIX_WHATSAPP_ENCRYPTION_VERIFICATION_LEVELS_SHARE = cfg.encryption.verificationLevel;
      } // cfg.environment;
      extraOptions = [
        "--net" clib.defaults.network.name
        "--ip" containerIP
      ];
      dependsOn = [ "synapse" ];
    };
  };
}
