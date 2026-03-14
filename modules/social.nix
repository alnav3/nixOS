{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    vesktop
    teamspeak6-client
    signal-desktop
    tg
    revolt-desktop
    _64gram
  ];

}
