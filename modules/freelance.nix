{  pkgs,
   pkgs-unstable,
   ...
}:
{

  # required packages for my actual projects
  environment.systemPackages = with pkgs; [
    go-migrate
    postgresql
    bruno
    pkgs-unstable.dbeaver-bin
    lunatask
    slack
    anydesk
  ];
}
