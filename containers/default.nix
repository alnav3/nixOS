{ config, lib, pkgs, ... }:

{
  imports = [
    # Core infrastructure
    ./nginx.nix
    
    # Media management (*arr stack)
    ./sonarr.nix
    ./radarr.nix
    ./prowlarr.nix
    ./bazarr.nix
    ./jellyseerr.nix
    ./suggestarr.nix
    
    # Download clients
    ./transmission.nix
    ./deemix.nix
    ./metube.nix
    ./slskd.nix
    
    # Media libraries
    ./calibre-web.nix
    
    # Photo management
    ./immich.nix
    
    # Communication (Matrix)
    ./synapse.nix
    ./mautrix-whatsapp.nix
    ./mautrix-telegram.nix
    ./mautrix-signal.nix
    
    # Utilities
    ./ntfy.nix
    ./searx.nix
    ./pihole.nix
    ./syncthing.nix
    ./etesync.nix
    ./trmnl.nix
    
    # Development/Infrastructure
    ./infisical.nix
    ./kasm.nix
    
    # Disabled/Optional (commented in original config)
    # ./headscale.nix
    # ./windmill.nix
    # ./traefik.nix
    # ./dokploy.nix
    # ./splitweb.nix
  ];
}
