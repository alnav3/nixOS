{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    vesktop
    signal-desktop
  ]
  ++
  [_64gram];

}
