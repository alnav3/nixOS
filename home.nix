{
  pkgs,
  inputs,
  ...
}: let
  additionalJDKs = with pkgs; [
    temurin-bin-11
    temurin-bin-17
  ];
in {
  programs.home-manager.enable = true;
  programs.kitty = {
    enable = true;
    settings = {
      confirm_os_window_close = 0;
    };
  };
  home.username = "alnav";
  home.homeDirectory = "/home/alnav";
  home.stateVersion = "24.05";

  # Git config
  programs.git = {
    enable = true;
    extraConfig = {
      credential.helper = "${
          pkgs.git.override { withLibsecret = true; }
        }/bin/git-credential-libsecret";
      push = { autoSetupRemote = true; };
    };
  };


  home.file = {
    # zsh plugins & config
    ".local/share/zsh/zsh-autosuggestions".source = "${pkgs.zsh-autosuggestions}/share/zsh/zsh-autosuggestions";
    ".local/share/zsh/zsh-syntax-highlighting".source = "${pkgs.zsh-syntax-highlighting}/share/zsh/site-functions";
    ".local/share/zsh/nix-zsh-completions".source = "${pkgs.nix-zsh-completions}/share/zsh/plugins/nix";
    ".zshrc".source = "${inputs.dotfiles}/zsh/.zshrc";
    ".config/oh-my-posh/zen.toml".source = "${inputs.dotfiles}/zsh/.config/oh-my-posh/zen.toml";

    # nvim config
    ".config/nvim".source = "${inputs.dotfiles}/nvim";

    # desktop config
    ".config/hypr.bak".source = "${inputs.dotfiles}/hypr";
    "wallpapers".source = "${inputs.dotfiles}/wallpapers";

    # tmux config
    ".tmux.conf".source = "${inputs.dotfiles}/tmux/.tmux.conf";
    "/.tmux/plugins/tpm".source = "${inputs.tpm}";
  };

  #(builtins.listToAttrs (builtins.map(jdk: {
  #    name = ".jdks/jdk.version";
  #    value = { source = jdk; };
  #}) additionalJDKs));
}
