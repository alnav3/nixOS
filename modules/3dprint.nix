{pkgs, ...}:
{
    environment.systemPackages = with pkgs; [
      orca-slicer
      openscad
      freecad
    ];
}
