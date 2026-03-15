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

    kanshi.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable kanshi configuration";
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
      (hlib.helpers.mkDotfile inputs "nvim" ".config/nvim.bak")
    ];

    # Hyprland configuration
    hyprFiles = lib.optionals cfg.hypr.enable [
      (hlib.helpers.mkDotfile inputs "hypr" ".config/hypr.bak")
    ];

    # Tmux configuration
    tmuxFiles = lib.optionals cfg.tmux.enable [
      (hlib.helpers.mkDotfile inputs "tmux/.tmux.conf" ".tmux.conf.bak")
      {
        name = "/.tmux/plugins/tpm";
        value.source = "${inputs.tpm}";
      }
    ];

    # Wallpapers
    wallpaperFiles = lib.optionals cfg.wallpapers.enable [
      (hlib.helpers.mkDotfile inputs "wallpapers" "wallpapers")
    ];

    # Kanshi configuration
    kanshiFiles = lib.optionals cfg.kanshi.enable [
      (hlib.helpers.mkDotfile inputs "kanshi/config" ".config/kanshi/config.test")
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
      ++ tmuxFiles 
      ++ wallpaperFiles 
      ++ kanshiFiles 
      ++ llmLsFiles 
      ++ cfg.extraFiles;

  in {
    home.file = hlib.helpers.mkStaticFiles allFiles;
  });
}