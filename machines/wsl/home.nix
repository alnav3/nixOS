{
  pkgs,
  inputs,
  ...
}: let
  additionalJDKs = with pkgs; [
    temurin-bin-11
    temurin-bin-17
    temurin-bin-21
  ];

  # Convertir archivos estáticos en una lista explícita
  staticFiles = [
    {
      name = ".local/share/zsh/zsh-autosuggestions";
      value.source = "${pkgs.zsh-autosuggestions}/share/zsh/zsh-autosuggestions";
    }
    {
      name = ".local/share/zsh/zsh-syntax-highlighting";
      value.source = "${pkgs.zsh-syntax-highlighting}/share/zsh/site-functions";
    }
    {
      name = ".local/share/zsh/nix-zsh-completions";
      value.source = "${pkgs.nix-zsh-completions}/share/zsh/plugins/nix";
    }
    {
      name = ".zshrc";
      value.source = "${inputs.dotfiles}/zsh/.zshrc";
    }
    {
      name = ".config/oh-my-posh/zen.toml";
      value.source = "${inputs.dotfiles}/zsh/.config/oh-my-posh/zen.toml";
    }

    # nvim config
    {
      name = ".config/nvim";
      value.source = "${inputs.dotfiles}/nvim";
    }

    # tmux config
    {
      name = ".tmux.conf";
      value.source = "${inputs.dotfiles}/tmux/.tmux.conf";
    }
    {
      name = "/.tmux/plugins/tpm";
      value.source = "${inputs.tpm}";
    }
    # lua-language-server for mason and nvim
    {
      name = ".local/share/nvim/mason/bin/lua-language-server.bak";
      value.source = "${pkgs.lua-language-server}/bin/lua-language-server";
    }
    {
      name = ".local/share/llm-ls/llm-ls";
      value.source = "${pkgs.llm-ls}/bin/llm-ls";
    }

  ];

  # Generar configuraciones dinámicas para JDKs con nombres únicos
  generatedFiles =
    builtins.map (jdk: {
      name = ".jdks/${jdk.version}";
      value.source = jdk;
    })
    additionalJDKs;
in {
  programs.home-manager.enable = true;

  home.username = "alnav";
  home.homeDirectory = "/home/alnav";
  home.stateVersion = "26.05";

  # Git config (without credential helper override)
  programs.git = {
    enable = true;
    settings = {
      push = {autoSetupRemote = true;};
    };
  };

  # opensnitch running in the background
  #services.opensnitch-ui.enable = true;

  # Concatenar las listas de archivos estáticos y generados
  home.file = builtins.listToAttrs (staticFiles ++ generatedFiles);
}
