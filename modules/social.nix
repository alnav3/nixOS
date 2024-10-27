{pkgs, pkgs-stable, ...}: {
  environment.systemPackages = with pkgs; [
    vesktop
    signal-desktop
  ]
  ++
  [pkgs-stable._64gram];

}
