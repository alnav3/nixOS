{pkgs-stable, ...}: {
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };
  environment.systemPackages = with pkgs-stable; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    libva-utils
  ];
  environment.sessionVariables = {LIBVA_DRIVER_NAME = "iHD";};
}
