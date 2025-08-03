{pkgs, ...}:
{
  virtualisation.waydroid.enable = true;
  environment.systemPackages = with pkgs; [
    scrcpy
    wlr-randr
    cage
  ];
}
