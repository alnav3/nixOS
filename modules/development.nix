{ config, lib, pkgs, pkgs-stable, inputs, postingPkg ? null, ... }:

let
  cfg = config.mymodules.development;
  mlib = import ./_lib { inherit lib; };
in
{
  options.mymodules.development = {
    enable = lib.mkEnableOption "Development environment";

    # Shell configuration
    shell = {
      zsh = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable ZSH as default shell with plugins";
        };

        aliases = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "Additional shell aliases";
        };
      };

      direnv = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable direnv for per-directory environments";
      };
    };

    # Programming languages
    languages = {
      go = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Go development tools";
      };

      nodejs = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Node.js development tools";
      };

      java = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Java development tools";
      };

      nix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Nix development tools";
      };

      python = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Python development tools";
      };
    };

    # Infrastructure/DevOps tools
    infrastructure = {
      kubernetes = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Kubernetes tools (kubectl, helm, etc.)";
      };

      dockerTools = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Docker CLI tools (docker-compose)";
      };

      databases = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable database tools (postgresql, dbeaver, etc.)";
      };
    };

    # Editor configuration
    editor = {
      neovim = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Neovim editor";
      };

      tmux = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable tmux terminal multiplexer";
      };

      opencode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable OpenCode AI coding assistant";
      };
    };

    # Git configuration
    git = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Git and related tools";
      };

      gitlab = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GitLab CLI (glab)";
      };
    };

    # Work-related tools
    work = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable work-related tools (VPN, Teams, etc.)";
      };
    };

    # Freelance/project-specific tools
    freelance = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable freelance project tools";
      };
    };

    # Extra packages
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional development packages";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Base development configuration
    {
      # nix-ld for language servers
      programs.nix-ld.enable = true;
      programs.nix-ld.libraries = with pkgs; [
        stdenv.cc.cc
        zlib
        fuse3
        icu
        nss
        openssl
        curl
        expat
      ];

      nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

      # Symlink for compatibility
      systemd.tmpfiles.rules = [
        "L+ /usr/local/bin - - - - /run/current-system/sw/bin"
      ];

      # Base development packages
      environment.systemPackages = with pkgs; [
        # Core utilities
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
      ] ++ cfg.extraPackages;

      # Gnome keyring for credentials
      services.gnome.gnome-keyring.enable = true;
    }

    # ZSH configuration
    (lib.mkIf cfg.shell.zsh.enable {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestions.enable = true;
        syntaxHighlighting.enable = true;
        shellAliases = {
          cl = "clear";
          update = "sudo nixos-rebuild switch --flake '/home/alnav/nixOS#${config.networking.hostName}'";
          clean-disk = "sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 1d";
          rofi-wifi = "${inputs.rofi-wifi}/rofi-wifi-menu.sh";
          update-flake = "nix flake lock --update-input";
          mjolnir = "ssh mjolnir";
          deck = "ssh deck";
          node0 = "ssh node0";
          wsl = "ssh wsl";
        } // cfg.shell.zsh.aliases;
      };
      users.defaultUserShell = pkgs.zsh;

      environment.systemPackages = with pkgs; [
        carapace
        oh-my-posh
        zsh-autosuggestions
        zsh-fzf-history-search
        zsh-vi-mode
      ];
    })

    # Direnv
    (lib.mkIf cfg.shell.direnv {
      programs.direnv.enable = true;
    })

    # Go development
    (lib.mkIf cfg.languages.go {
      environment.systemPackages = with pkgs; [
        go
        gcc # required for debug
        air
        goose
        sqlc
        templ
      ];
    })

    # Node.js development
    (lib.mkIf cfg.languages.nodejs {
      environment.systemPackages = with pkgs; [
        nodejs_22
        tailwindcss_4
      ];
    })

    # Java development
    (lib.mkIf cfg.languages.java {
      environment.systemPackages = with pkgs; [
        temurin-bin-21
        maven
        gradle
      ];
    })

    # Nix development
    (lib.mkIf cfg.languages.nix {
      environment.systemPackages = with pkgs; [
        alejandra
        nixd
      ];
    })

    # Python development
    (lib.mkIf cfg.languages.python {
      environment.systemPackages = with pkgs; [
        python313
        python313Packages.pip
      ];
    })

    # Kubernetes tools
    (lib.mkIf cfg.infrastructure.kubernetes {
      environment.systemPackages = with pkgs; [
        kubectl
        kubernetes-helm
        helmfile
        kaf
      ];
    })

    # Docker CLI tools
    (lib.mkIf cfg.infrastructure.dockerTools {
      environment.systemPackages = with pkgs; [
        docker-compose
      ];
    })

    # Tmux
    (lib.mkIf cfg.editor.tmux {
      environment.systemPackages = [ pkgs.tmux ];
    })

    # OpenCode
    (lib.mkIf cfg.editor.opencode {
      environment.systemPackages = [ pkgs.opencode ];
    })

    # Database tools
    (lib.mkIf cfg.infrastructure.databases {
      environment.systemPackages = with pkgs; [
        postgresql
        turso-cli
      ] ++ (if pkgs-stable != null then [ pkgs-stable.dbeaver-bin ] else []);
    })

    # Neovim
    (lib.mkIf cfg.editor.neovim (let
      # Treesitter grammars path for preinstalled grammars
      grammarsPath = pkgs.symlinkJoin {
        name = "nvim-treesitter-grammars";
        paths = pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies;
      };

      # Lua config snippet to add grammars to runtimepath
      treesitterLuaConfig = ''
        -- Append treesitter plugin (bundles some languages)
        vim.opt.runtimepath:append("${pkgs.vimPlugins.nvim-treesitter}")
        -- Append all compiled Treesitter grammars (*.so files)
        vim.opt.runtimepath:append("${grammarsPath}")
      '';
    in {
      environment.systemPackages = with pkgs; [
        pkgs-stable.neovim
        tree-sitter
      ];

      # Create a file with the Lua config for easy sourcing in your init.lua
      environment.etc."xdg/nvim/treesitter-nix.lua".text = treesitterLuaConfig;
    }))

    # Git tools
    (lib.mkIf cfg.git.enable {
      environment.systemPackages = with pkgs; [
        git
      ] ++ (lib.optionals cfg.git.gitlab [ glab ]);
    })

    # Work tools
    (lib.mkIf cfg.work.enable {
      environment.systemPackages = with pkgs; [
        teams-for-linux
      ];
    })

    # Freelance tools
    (lib.mkIf cfg.freelance.enable {
      environment.systemPackages = with pkgs; [
        go-migrate
        bruno
        love  # Game development
      ] ++ (lib.optionals (postingPkg != null) [ postingPkg ]);
    })
  ]);
}
