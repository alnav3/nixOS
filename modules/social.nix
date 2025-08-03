{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    vesktop
    signal-desktop
    tg
    revolt-desktop
    _64gram
  ];

}
