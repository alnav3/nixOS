{pkgs, ...}:
{

    services.ollama ={
        enable = true;
        acceleration = "rocm";
        host = "[::]";
        openFirewall = true;
        environmentVariables = {
            HSA_OVERRIDE_GFX_VERSION = "11.0.0";
        };
    };

    environment.systemPackages = with pkgs; [
      jan
    ];
}
