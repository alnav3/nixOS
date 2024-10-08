{config, pkgs, ...}:
let
  additionalJDKs = with pkgs; [
  temurin-bin-11
  temurin-bin-17
  ];
in
{
    programs.home-manager.enable = true;
    home.username = "alnav";
    home.homeDirectory = "/home/alnav";
    home.stateVersion = "24.05";

#    home.files = {
#      ".local/share/zsh/zsh-autosuggestions".source = "${pkgs.zsh-autosuggestions}/share/zsh/zsh-autosuggestions";
#      ".local/share/zsh/zsh-syntax-highlighting".source = "${pkgs.zsh-syntax-highlighting}/share/zsh/site-functions";
#      ".local/share/zsh/nix-zsh-completions".source = "${pkgs.nix-zsh-completions}/share/zsh/plugins/nix";
#    };
    # i have to think about it
    #home.file = (builtins.listToAttrs (builtins.map(jdk: {
    #    name = ".jdks/jdk.version";
    #    value = { source = jdk; };
    #}) additionalJDKs));
}
