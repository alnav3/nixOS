{
  pkgs,
  pkgs-stable,
  inputs,
  ...
}: {
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs-stable.base16-schemes}/share/themes/catppuccin-mocha.yaml";
  stylix.image = "${inputs.dotfiles}/wallpapers/comfy-home.png";
  #stylix.icons = {
  #    enable = true;
  #    dark = "";
  #};
  stylix.cursor = {
    package = pkgs.rose-pine-cursor;
    name = "BreezeX-RosePine-Linux";
    size = 24;
  };
  stylix.fonts = {
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
  stylix.polarity = "dark";

}
