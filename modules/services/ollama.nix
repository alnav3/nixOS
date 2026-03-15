{ config, lib, pkgs, ... }:

let
  cfg = config.mymodules.services.ollama;
in
{
  options.mymodules.services.ollama = {
    enable = lib.mkEnableOption "Ollama LLM service";

    acceleration = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "rocm" "cuda" ]);
      default = null;
      description = "GPU acceleration type (rocm for AMD, cuda for NVIDIA)";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address to bind to";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open Ollama port in firewall";
    };

    # AMD-specific GFX version override
    amdGfxVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "HSA_OVERRIDE_GFX_VERSION for AMD GPUs (e.g., 11.0.0)";
    };

    # Extra packages (like Jan for UI)
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional LLM-related packages";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      host = cfg.host;
      openFirewall = cfg.openFirewall;
    } // (lib.optionalAttrs (cfg.acceleration != null) {
      acceleration = cfg.acceleration;
    }) // (lib.optionalAttrs (cfg.amdGfxVersion != null) {
      environmentVariables = {
        HSA_OVERRIDE_GFX_VERSION = cfg.amdGfxVersion;
      };
    });

    environment.systemPackages = cfg.extraPackages;
  };
}
