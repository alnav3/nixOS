{pkgs, inputs, ...}:
{
    stylix.enable = true;
    stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    stylix.image = "${inputs.dotfiles}/wallpapers/comfy-home.png";
    stylix.cursor = {
        package = pkgs.rose-pine-cursor;
        name = "BreezeX-RosePine-Linux";
        size = 24;
    };
    stylix.fonts.sizes.terminal = 16;

}
