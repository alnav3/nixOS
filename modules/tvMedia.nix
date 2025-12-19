{pkgs, ...}: {
  services.xserver.desktopManager.kodi = {
      enable = true;
      package = pkgs.kodi-wayland.withPackages (kodiPkgs: with kodiPkgs; [
        inputstream-adaptive
      ]);
  };
}

