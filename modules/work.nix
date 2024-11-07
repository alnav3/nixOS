{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    openfortivpn
    teams-for-linux
  ];
}
