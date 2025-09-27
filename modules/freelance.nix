{  pkgs,
   pkgs-unstable,
   pkgs-stable,
   ...
}:
{

  # required packages for my actual projects
  environment.systemPackages = with pkgs; [
    go-migrate
    postgresql
    bruno
    pkgs-unstable.dbeaver-bin
    #lunatask
    #google-cloud-sdk
    # Game development
    love
    #anydesk
  ];
}
