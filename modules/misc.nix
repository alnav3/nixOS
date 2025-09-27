{pkgs, ...}:
{
  environment.systemPackages =
    (with pkgs; [
      gum
      ]);
}
