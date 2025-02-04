{  pkgs,
  inputs,
  lib,
  ...
}:
{

  # required packages for my actual projects
  environment.systemPackages = with pkgs; [
    go-migrate
    postgresql
    bruno
    dbeaver-bin
    lunatask
  ];
}
