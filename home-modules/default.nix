{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./user.nix
    ./git.nix
    ./dotfiles.nix
    ./jdk.nix
    ./kitty.nix
    ./hyprpanel.nix
    ./neovim.nix
  ];

  # Default configuration that enables basic functionality
  options.myhome = {
    enable = lib.mkEnableOption "home-manager modular configuration" // {
      default = true;
    };
  };

  config = lib.mkIf config.myhome.enable {
    # Enable user configuration by default
    myhome.user.enable = lib.mkDefault true;
  };
}