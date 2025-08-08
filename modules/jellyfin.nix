{ pkgs, ... }: {
  # Enable OpenGL and hardware acceleration (crucial for transcoding)
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver  # For Broadwell (5th gen) or newer; enables QSV/VA-API
      intel-vaapi-driver  # For older Intel chips (set LIBVA_DRIVER_NAME = "i965" if needed)
      intel-compute-runtime  # OpenCL for tone mapping and advanced features
      vpl-gpu-rt  # QSV for 11th gen+ Intel
      intel-media-sdk  # QSV for up to 11th gen
      vaapiVdpau  # Additional VA-API support
    ];
  };

  # Optional: Kernel params for better Intel QSV performance
  boot.kernelParams = [ "i915.enable_guc=2" ];

  # Jellyfin service
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg  # Customized FFmpeg for Jellyfin transcoding
    libva-utils  # For testing VA-API (run vainfo to verify)
  ];

  # Environment variable for Intel driver
  environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; };

  # Override for hybrid codec support (optional but recommended)
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."tv.home" = {
      serverName = "tv.home";
      listen = [{ addr = "10.71.71.13"; port = 80; }];
      locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
          '';
      };
  };
  networking.extraHosts = "10.71.71.13 tv.home";

}

