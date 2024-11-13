{
  pkgs,
  inputs,
  ...
}: {
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
  stylix.image = "${inputs.dotfiles}/wallpapers/comfy-home.png";
  stylix.cursor = {
    package = pkgs.rose-pine-cursor;
    name = "breezex-rosepine-linux";
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
      package = pkgs.nerdfonts.override {fonts = ["FiraCode"];};
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
}
