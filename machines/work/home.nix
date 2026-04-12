# Standalone Home Manager configuration for work laptop (Fedora Workstation)
#
# This replaces the NixOS system configuration with a user-level Home Manager
# config. System-level services (Docker, TLP, Bluetooth, etc.) must be
# configured on Fedora directly - see fedora-config.md.
#
# Usage:
#   home-manager switch --flake '/home/alnav/nixOS#alnav@work'
#
{ pkgs, lib, inputs, pkgs-stable, meta, ... }:

let
  # Treesitter grammars for Neovim (from modules/development.nix)
  grammarsPath = pkgs.symlinkJoin {
    name = "nvim-treesitter-grammars";
    paths = pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies;
  };
  treesitterLuaConfig = ''
    -- Append treesitter plugin (bundles some languages)
    vim.opt.runtimepath:append("${pkgs.vimPlugins.nvim-treesitter}")
    -- Append all compiled Treesitter grammars (*.so files)
    vim.opt.runtimepath:append("${grammarsPath}")
  '';

  postingPkg = inputs.posting-flake.packages.${pkgs.system}.posting or null;
in
{
  imports = [ ../../home-modules ];

  # ===========================================================================
  # Home Module Configuration (same options as original NixOS work config)
  # ===========================================================================

  myhome = {
    user.enable = true;

    git.enable = true;
    jdk.enable = true;

    kitty.enable = true;

    hyprpanel.enable = true;

    neovim = {
      enable = true;
      javaSupport = true;
    };

    dotfiles = {
      enable = true;
      zsh.enable = true;
      nvim.enable = true;
      hypr.enable = true;
      hyprdynamicmonitors.enable = true;
      hyprpanel.enable = true;
      rofi.enable = true;
      tmux.enable = true;
      wallpapers.enable = true;
      llmLs.enable = true;
    };
  };

  # ===========================================================================
  # Session Variables
  # ===========================================================================

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    # Intel VA-API driver
    LIBVA_DRIVER_NAME = "iHD";
  };

  # ===========================================================================
  # Packages (consolidated from all NixOS modules)
  # ===========================================================================

  home.packages = with pkgs; [
    # --- Desktop environment (from modules/desktop.nix) ---
    kitty
    hyprcursor
    hyprpaper
    rofi
    hyprlock
    networkmanagerapplet
    adwaita-icon-theme
    bc
    imv
    shikane
    proton-pass
    hyprsunset
    localsend
    (waybar.overrideAttrs (oldAttrs: {
      mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
    }))

    # Hyprland compositor + portals
    inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland
    inputs.hyprdynamicmonitors.packages.${pkgs.system}.default
    xdg-desktop-portal-gtk
    inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland

    # Browsers
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    (ungoogled-chromium.override {
      commandLineArgs = [
        "--enable-features=VaapiVideoDecoder"
        "--enable-remote-extensions"
      ];
    })
    floorp-bin

    # File managers
    nautilus
    yazi
    gnome-multi-writer

    # Notifications
    swaynotificationcenter
    libnotify

    # Screenshots & recording
    hyprshot
    wf-recorder

    # --- Development tools (from modules/development.nix) ---
    # Core CLI utilities
    bat
    eza
    fzf
    jq
    ripgrep
    tmux
    tree-sitter
    unzip
    wl-clipboard
    zoxide
    lsof

    # Secret management
    infisical

    # ZSH plugins/tools
    carapace
    oh-my-posh
    zsh-autosuggestions
    zsh-fzf-history-search
    zsh-vi-mode

    # Go
    go
    gcc
    air
    goose
    sqlc
    templ

    # Node.js
    nodejs_22
    tailwindcss_4

    # Java
    temurin-bin-21
    maven
    gradle

    # Nix tools
    alejandra
    nixd

    # Python
    python313
    python313Packages.pip

    # Kubernetes
    kubectl
    kubernetes-helm
    helmfile
    kaf

    # Docker CLI
    docker-compose

    # Database tools
    postgresql
    turso-cli
    pkgs-stable.dbeaver-bin

    # Neovim
    pkgs-stable.neovim

    # Git
    git
    glab

    # Work tools
    teams-for-linux

    # Freelance tools
    go-migrate
    bruno
    love
  ] ++ (lib.optionals (postingPkg != null) [ postingPkg ]) ++ (with pkgs; [

    # --- Media (from modules/media.nix) ---
    obs-studio
    playerctl
    zathura
    thunderbird
    pika-backup
    glib.bin
    glib.dev

    # --- Networking tools (from modules/networking.nix) ---
    nfs-utils
    ethtool
    iw
    wireguard-tools

    # Work VPN (from machines/work/configuration.nix)
    openconnect
    networkmanager-openconnect
    gum

    # --- Bluetooth tools (from modules/hardware/bluetooth.nix) ---
    bluez
    bluez-tools
    rofi-bluetooth
    alsa-utils
    pavucontrol
    easyeffects

    # --- Power management tools (from modules/hardware/battery.nix) ---
    brightnessctl
    btop
    powertop
    hypridle
    acpi

    # --- Base utilities (from modules/base.nix) ---
    cifs-utils
    age
    sops
    killall
  ]);

  # ===========================================================================
  # Treesitter Grammars for Neovim
  # ===========================================================================

  xdg.configFile."nvim/treesitter-nix.lua".text = treesitterLuaConfig;

  # ===========================================================================
  # ZSH Configuration (replaces NixOS-level programs.zsh)
  # ===========================================================================

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      cl = "clear";
      update = "home-manager switch --flake '/home/alnav/nixOS#alnav@work'";
      clean-disk = "nix profile wipe-history --older-than 1d";
      rofi-wifi = "${inputs.rofi-wifi}/rofi-wifi-menu.sh";
      update-flake = "nix flake lock --update-input";
      mjolnir = "ssh mjolnir";
      deck = "ssh deck";
      node0 = "ssh node0";
      wsl = "ssh wsl";
    };
    initExtra = ''
      # Source custom zshrc from dotfiles if present
      [[ -f ~/.zshrc.bak ]] && source ~/.zshrc.bak
    '';
  };

  # ===========================================================================
  # Direnv
  # ===========================================================================

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # ===========================================================================
  # Stylix Theming (Home Manager module)
  # ===========================================================================

  stylix = {
    enable = true;
    base16Scheme = "${pkgs-stable.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    image = ../../dotfiles/wallpapers/comfy-home.png;
    polarity = "dark";
    cursor = {
      package = pkgs.rose-pine-cursor;
      name = "BreezeX-RosePine-Linux";
      size = 24;
    };
    fonts = {
      sizes = {
        terminal = 16;
        applications = 12;
        desktop = 10;
        popups = 10;
      };
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
    };
    targets.gtk.enable = true;
  };

  # ===========================================================================
  # Syncthing (user-level service via Home Manager)
  # ===========================================================================

  services.syncthing.enable = true;

  # ===========================================================================
  # Systemd User Services
  # ===========================================================================

  # MPRIS proxy for Bluetooth headset controls (from hardware/bluetooth.nix)
  systemd.user.services.mpris-proxy = {
    Unit = {
      Description = "Mpris proxy";
      After = [ "network.target" "sound.target" ];
    };
    Install.WantedBy = [ "default.target" ];
    Service.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
  };

  # hyprdynamicmonitors prepare (from modules/desktop.nix)
  systemd.user.services.hyprdynamicmonitors-prepare = {
    Unit = {
      Description = "hyprdynamicmonitors prepare";
      Before = [ "graphical-session-pre.target" ];
    };
    Install.WantedBy = [ "default.target" "graphical-session-pre.target" ];
    Service = {
      Type = "oneshot";
      ExecStart = "${inputs.hyprdynamicmonitors.packages.${pkgs.system}.default}/bin/hyprdynamicmonitors prepare";
      TimeoutStartSec = "3";
      RemainAfterExit = "yes";
    };
  };

  # ===========================================================================
  # Chromium Extension Policy (user-level)
  # ===========================================================================

  xdg.configFile."chromium/policies/managed/extensions.json".text = builtins.toJSON {
    ExtensionSettings = {
      "*" = {
        allowed_types = [ "extension" "theme" "user_script" ];
        blocked_install_message = "Extensions are allowed.";
        install_sources = [ "*" ];
        installation_mode = "allowed";
      };
    };
    ExtensionInstallBlocklist = [];
    ExtensionInstallAllowlist = [ "*" ];
  };
}
