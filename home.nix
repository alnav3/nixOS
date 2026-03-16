{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./home-modules
  ];

  # Configuration that matches the original home.nix exactly
  myhome = {
    # Basic user configuration
    user.enable = true;

    # Git configuration
    git.enable = true;

    # JDK management
    jdk.enable = true;

    # Kitty terminal
    kitty.enable = true;

    # Hyprpanel desktop panel
    hyprpanel.enable = true;

    # Neovim with Java support
    neovim = {
      enable = true;
      javaSupport = true;
    };

    # Dotfiles and static file management
    dotfiles = {
      enable = true;
      zsh.enable = true;
      nvim.enable = true;
      hypr.enable = true;
      hyprdynamicmonitors.enable = true;
      tmux.enable = true;
      wallpapers.enable = true;
      llmLs.enable = true;
    };
  };

  # Commented out service - preserve as comment for reference
  # services.opensnitch-ui.enable = true;
}
