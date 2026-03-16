{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  hlib = import ./_lib {inherit lib;};
  cfg = config.myhome.dotfiles;
in {
  options.myhome.dotfiles = {
    enable = lib.mkEnableOption "dotfiles and static files";

    zsh.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable zsh configuration and plugins";
    };

    nvim.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable nvim configuration";
    };

    hypr.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable hyprland configuration";
    };

    hyprdynamicmonitors.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable hyprdynamicmonitors configuration";
    };

    hyprpanel.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable hyprpanel configuration";
    };

    rofi.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable rofi configuration";
    };

    tmux.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable tmux configuration";
    };

    wallpapers.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable wallpapers";
    };

    llmLs.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable LLM language server";
    };

    extraFiles = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [];
      description = "Additional static files to configure";
    };
  };

  config = lib.mkIf cfg.enable (let
    # ZSH related files
    zshFiles = lib.optionals cfg.zsh.enable [
      (hlib.helpers.mkZshPlugin pkgs "zsh-autosuggestions" ".local/share/zsh/zsh-autosuggestions" "share/zsh/zsh-autosuggestions")
      (hlib.helpers.mkZshPlugin pkgs "zsh-syntax-highlighting" ".local/share/zsh/zsh-syntax-highlighting" "share/zsh/site-functions")
      (hlib.helpers.mkZshPlugin pkgs "nix-zsh-completions" ".local/share/zsh/nix-zsh-completions" "share/zsh/plugins/nix")
      (hlib.helpers.mkDotfile inputs "zsh/.zshrc" ".zshrc")
      (hlib.helpers.mkDotfile inputs "zsh/.config/oh-my-posh/zen.toml" ".config/oh-my-posh/zen.toml")
    ];

    # Nvim configuration
    nvimFiles = lib.optionals cfg.nvim.enable [
      (hlib.helpers.mkDotfile inputs "nvim" ".config/nvim")
    ];

    hyprFiles = lib.optionals cfg.hypr.enable [
      (hlib.helpers.mkDotfile inputs "hypr/scripts"        ".config/hypr/scripts")
      (hlib.helpers.mkDotfile inputs "hypr/hypridle.conf"  ".config/hypr/hypridle.conf")
      (hlib.helpers.mkDotfile inputs "hypr/hyprland.conf"  ".config/hypr/hyprland.conf")
      (hlib.helpers.mkDotfile inputs "hypr/hyprlock.conf"  ".config/hypr/hyprlock.conf")
      (hlib.helpers.mkDotfile inputs "hypr/hyprpaper.conf" ".config/hypr/hyprpaper.conf")
      (hlib.helpers.mkDotfile inputs "hypr/mocha.conf"     ".config/hypr/mocha.conf")
    ];

    # hyprdynamicmonitors configuration
    hyprdynamicmonitorsFiles = lib.optionals cfg.hyprdynamicmonitors.enable [
      (hlib.helpers.mkDotfile inputs "hyprdynamicmonitors" ".config/hyprdynamicmonitors")
    ];

    # hyprdynamicmonitors configuration
    hyprpanelFiles = lib.optionals cfg.hyprpanel.enable [
      (hlib.helpers.mkDotfile inputs "hyprpanel" ".config/hyprpanel")
    ];

    # rofi configuration
    rofiFiles = lib.optionals cfg.rofi.enable [
      (hlib.helpers.mkDotfile inputs "rofi" ".config/rofi")
    ];

    # Tmux configuration
    tmuxFiles = lib.optionals cfg.tmux.enable [
      (hlib.helpers.mkDotfile inputs "tmux/.tmux.conf" ".tmux.conf")
      {
        name = "/.tmux/plugins/tpm";
        value.source = "${inputs.tpm}";
      }
    ];

    # Wallpapers
    wallpaperFiles = lib.optionals cfg.wallpapers.enable [
      (hlib.helpers.mkDotfile inputs "wallpapers" "wallpapers")
    ];

    # LLM Language Server
    llmLsFiles = lib.optionals cfg.llmLs.enable [
      {
        name = ".local/share/llm-ls/llm-ls";
        value.source = "${pkgs.llm-ls}/bin/llm-ls";
      }
    ];

    # All static files combined
    allFiles =
      zshFiles
      ++ nvimFiles
      ++ hyprFiles
      ++ hyprdynamicmonitorsFiles
      ++ hyprpanelFiles
      ++ rofiFiles
      ++ tmuxFiles
      ++ wallpaperFiles
      ++ llmLsFiles
      ++ cfg.extraFiles;

  in {
    home.file = hlib.helpers.mkStaticFiles allFiles;
  });
}
