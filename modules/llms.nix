{pkgs, ...}:
{
    #services.open-webui.enable = true;
    services.ollama.enable = true;
    environment.systemPackages = with pkgs; [
      jan
    ];
}
