{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # WireGuard VPN Client Configuration
  # ===========================================================================
  # This module configures the router as a WireGuard VPN client.
  # 
  # Purpose:
  # - Provides an encrypted tunnel for all LAN traffic (default route)
  # - Privacy and security: ISP cannot see browsing traffic
  # - Bypasses geo-restrictions and censorship
  # 
  # Integration:
  # - Configuration stored in SOPS encrypted secret (vpn.conf)
  # - Automatically started/stopped with PPPoE connection
  # - Policy routing ensures VPN traffic bypasses wg0 itself (no recursion)
  # 
  # Manual control:
  #   systemctl start wg-quick-wg0    # Start VPN
  #   systemctl stop wg-quick-wg0     # Stop VPN
  # ===========================================================================

  # WireGuard interface configuration
  networking.wg-quick.interfaces.wg0 = {
    # Configuration file is encrypted with SOPS
    # Contains: private key, peer public key, endpoint, allowed IPs
    configFile = config.sops.secrets."vpn.conf".path;
    
    # Don't start automatically at boot
    # VPN is started by PPP ip-up script (after WAN is up)
    autostart = false;
  };

  # SOPS secret for WireGuard configuration
  # Keeps VPN credentials secure
  sops.secrets."vpn.conf" = { };

  # ---------------------------------------------------------------------------
  # PPP Integration: Start/Stop VPN with WAN Connection
  # ---------------------------------------------------------------------------
  # WireGuard requires working internet (ppp0) to connect
  # These scripts ensure VPN starts when WAN is up, stops when WAN is down

  # PPP ip-up hook: Executed when PPP connection is established
  environment.etc."ppp/ip-up" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      # Run all scripts in ip-up.d directory
      for s in /etc/ppp/ip-up.d/*; do
        [ -x "$s" ] && "$s" "$@"
      done
    '';
  };

  # PPP ip-down hook: Executed when PPP connection is terminated
  environment.etc."ppp/ip-down" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      # Run all scripts in ip-down.d directory
      for s in /etc/ppp/ip-down.d/*; do
        [ -x "$s" ] && "$s" "$@"
      done
    '';
  };

  # Start WireGuard when PPP comes up
  environment.etc."ppp/ip-up.d/01-wireguard" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      # Restart (not start) to handle reconnections cleanly
      ${pkgs.systemd}/bin/systemctl restart wg-quick-wg0.service
    '';
  };

  # Stop WireGuard when PPP goes down
  environment.etc."ppp/ip-down.d/01-wireguard" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      # Stop VPN when WAN is down (no point keeping it up)
      ${pkgs.systemd}/bin/systemctl stop wg-quick-wg0.service
    '';
  };
}
