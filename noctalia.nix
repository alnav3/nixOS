{ pkgs, inputs, ... }:
{
  # Install Noctalia shell package
  environment.systemPackages = with pkgs; [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}