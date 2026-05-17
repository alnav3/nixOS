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

    # When using home-manager's wayland.windowManager.hyprland module
    # (e.g. to load plugins), HM owns ~/.config/hypr/hyprland.conf and we
    # must NOT symlink our static one there. Set this true to drop the
    # hyprland.conf entry from the dotfiles bundle (all the other hypr
    # files - scripts, hypridle.conf, hyprlock.conf, etc. - are still dropped).
    hypr.skipMainConf = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Skip ~/.config/hypr/hyprland.conf (when HM owns it)";
    };

    # Also skip hyprpaper.conf when HM's hyprland module is enabled (it
    # creates one of its own via programs.hyprpaper or similar).
    hypr.skipHyprpaper = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Skip ~/.config/hypr/hyprpaper.conf (when HM owns it)";
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

    noctalia.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable noctalia-shell configuration (settings.json)";
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

    nwgDrawer.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable nwg-drawer configuration";
    };

    extraFiles = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [];
      description = "Additional static files to configure";
    };
  };

  config = lib.mkIf cfg.enable (let
    # Noctalia ships a full export (`{ settings, state }`) under
    # dotfiles/noctalia/noctalia.json. The runtime settings file expects only
    # the inner `settings` object. We extract it at eval time so the activation
    # script below seeds a faithful copy.
    noctaliaSettings = builtins.toFile "noctalia-settings.json"
      (builtins.toJSON
        (builtins.fromJSON
          (builtins.readFile ../dotfiles/noctalia/noctalia.json)).settings);
    # ZSH related files
    zshFiles = lib.optionals cfg.zsh.enable [
      (hlib.helpers.mkZshPlugin pkgs "zsh-autosuggestions" ".local/share/zsh/zsh-autosuggestions" "share/zsh/zsh-autosuggestions")
      (hlib.helpers.mkZshPlugin pkgs "zsh-syntax-highlighting" ".local/share/zsh/zsh-syntax-highlighting" "share/zsh/site-functions")
      (hlib.helpers.mkZshPlugin pkgs "nix-zsh-completions" ".local/share/zsh/nix-zsh-completions" "share/zsh/plugins/nix")
      (hlib.helpers.mkDotfile inputs "zsh/.zshrc" ".zshrc.bak")
      (hlib.helpers.mkDotfile inputs "zsh/.config/oh-my-posh/zen.toml" ".config/oh-my-posh/zen.toml")
    ];

    # Nvim configuration
    nvimFiles = lib.optionals cfg.nvim.enable [
      (hlib.helpers.mkDotfile inputs "nvim" ".config/nvim")
    ];

    hyprFiles = lib.optionals cfg.hypr.enable ([
      (hlib.helpers.mkDotfile inputs "hypr/scripts"        ".config/hypr/scripts")
      (hlib.helpers.mkDotfile inputs "hypr/hypridle.conf"  ".config/hypr/hypridle.conf")
      (hlib.helpers.mkDotfile inputs "hypr/hyprlock.conf"  ".config/hypr/hyprlock.conf")
      (hlib.helpers.mkDotfile inputs "hypr/mocha.conf"     ".config/hypr/mocha.conf")
    ] ++ lib.optionals (!cfg.hypr.skipMainConf) [
      (hlib.helpers.mkDotfile inputs "hypr/hyprland.conf"  ".config/hypr/hyprland.conf")
    ] ++ lib.optionals (!cfg.hypr.skipHyprpaper) [
      (hlib.helpers.mkDotfile inputs "hypr/hyprpaper.conf" ".config/hypr/hyprpaper.conf")
    ]);

    # hyprdynamicmonitors configuration
    hyprdynamicmonitorsFiles = lib.optionals cfg.hyprdynamicmonitors.enable [
      (hlib.helpers.mkDotfile inputs "hyprdynamicmonitors" ".config/hyprdynamicmonitors")
    ];

    # hyprdynamicmonitors configuration
    hyprpanelFiles = lib.optionals cfg.hyprpanel.enable [
      (hlib.helpers.mkDotfile inputs "hyprpanel" ".config/hyprpanel")
    ];

    # noctalia-shell configuration is seeded via home.activation below
    # (not as a symlink, so the noctalia UI can write to it)
    noctaliaFiles = [];

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

    # nwg-drawer configuration
    nwgDrawerFiles = lib.optionals cfg.nwgDrawer.enable [
      (hlib.helpers.mkDotfile inputs "nwg-drawer" ".config/nwg-drawer")
    ];

    # All static files combined
    allFiles =
      zshFiles
      ++ nvimFiles
      ++ hyprFiles
      ++ hyprdynamicmonitorsFiles
      ++ hyprpanelFiles
      ++ noctaliaFiles
      ++ rofiFiles
      ++ tmuxFiles
      ++ wallpaperFiles
      ++ llmLsFiles
      ++ nwgDrawerFiles
      ++ cfg.extraFiles;

  in {
    home.file = hlib.helpers.mkStaticFiles allFiles;

    # Noctalia: seed ~/.config/noctalia/settings.json as a writable copy.
    # We deliberately don't use home.file (which would symlink a read-only
    # store path) because noctalia's UI must be able to rewrite this file.
    # The copy only happens when the file is missing, so user edits made via
    # the noctalia UI are preserved across rebuilds.
    home.activation = lib.mkIf cfg.noctalia.enable {
      seedNoctaliaSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        target="$HOME/.config/noctalia/settings.json"
        if [ ! -e "$target" ] || [ -L "$target" ]; then
          # Remove any stale symlink from previous configurations
          [ -L "$target" ] && rm -f "$target"
          run mkdir -p "$(dirname "$target")"
          run install -m 644 ${noctaliaSettings} "$target"
        fi
      '';
    };
  });
}
