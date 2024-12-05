{pkgs, lib, ...}: {
  environment.systemPackages = with pkgs; [
    pika-backup
    glib.bin
    glib.dev
  ];
  services.gvfs = {
    enable = true;
    package = lib.mkForce pkgs.gnome.gvfs;
  };
}
