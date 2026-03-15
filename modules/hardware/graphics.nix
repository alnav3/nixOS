{ config, lib, pkgs, ... }:

let
  cfg = config.mymodules.hardware.graphics;
in
{
  options.mymodules.hardware.graphics = {
    enable = lib.mkEnableOption "Graphics configuration";

    # GPU type
    gpu = lib.mkOption {
      type = lib.types.enum [ "amd" "intel" "nvidia" "integrated" ];
      default = "amd";
      description = "Primary GPU type";
    };

    # AMD-specific options
    amd = {
      initrdEnable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Load AMD GPU drivers in initrd";
      };

      vulkan = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable AMD Vulkan support (RADV)";
      };

      opencl = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable AMD OpenCL support";
      };
    };

    # Intel-specific options
    intel = {
      vaapi = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Intel VA-API (video acceleration)";
      };

      qsv = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Intel QuickSync (11th gen+)";
      };

      openclCompute = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Intel OpenCL compute runtime";
      };
    };

    # 32-bit support (for games)
    enable32Bit = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable 32-bit graphics support (for gaming)";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Base graphics
    {
      hardware.graphics.enable = true;
      hardware.enableRedistributableFirmware = true;
    }

    # 32-bit support
    (lib.mkIf cfg.enable32Bit {
      hardware.graphics.enable32Bit = true;
    })

    # AMD GPU configuration
    (lib.mkIf (cfg.gpu == "amd") {
      services.xserver.videoDrivers = [ "amdgpu" ];

      hardware.amdgpu = {
        initrd.enable = cfg.amd.initrdEnable;
        opencl.enable = cfg.amd.opencl;
      };

      boot.initrd.kernelModules = lib.optionals cfg.amd.initrdEnable [ "amdgpu" ];

      environment.sessionVariables = lib.optionalAttrs cfg.amd.vulkan {
        AMD_VULKAN_ICD = "RADV";
      };
    })

    # Intel GPU configuration
    (lib.mkIf (cfg.gpu == "intel") {
      services.xserver.videoDrivers = [ "modesetting" ];

      hardware.graphics.extraPackages = with pkgs;
        (lib.optionals cfg.intel.vaapi [
          intel-media-driver
          libva-vdpau-driver
        ])
        ++ (lib.optionals cfg.intel.qsv [
          vpl-gpu-rt
        ])
        ++ (lib.optionals cfg.intel.openclCompute [
          intel-compute-runtime
        ]);

      hardware.graphics.extraPackages32 = lib.optionals (cfg.enable32Bit && cfg.intel.vaapi)
        (with pkgs.pkgsi686Linux; [
          intel-media-driver
        ]);

      environment.sessionVariables = lib.optionalAttrs cfg.intel.vaapi {
        LIBVA_DRIVER_NAME = "iHD";
      };

      hardware.intel-gpu-tools.enable = true;
    })
  ]);
}
