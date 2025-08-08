{pkgs, ...}:
{
    environment.systemPackages = with pkgs; [
      orca-slicer
      openscad
      freecad
    ];
    # TEMPORAL FIX for orca-slicer while they fix the issue with libgroup
    nixpkgs.config.permittedInsecurePackages = [
      "libsoup-2.74.3"
    ];
}
