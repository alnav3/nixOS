{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    _64gram
    vesktop
  ];
}
