{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # WireGuard VPN Client Configuration
  # ===========================================================================
  # This module configures the router as a WireGuard VPN client.
  # 
  # Three parallel WireGuard tunnels are provisioned:
  #
  #   wg0  — secure profile (vpn.conf)
  #          Default tunnel for all LAN traffic. wg-quick manages the default
  #          route via its own table + fwmark/suppress_prefixlength rules.
  #
  #   wg1  — fast profile (vpn.fast.conf)
  #          Same provider, faster/less-loaded endpoint. Started alongside
  #          wg0 but Table=off via post-start hooks — it does NOT steal the
  #          default route. Selected source IPs are sent to it via policy
  #          routing managed by the `vpn-fast` utility (see vpn-fast.nix).
  #
  #   wg2  — home profile (vpn.home.conf)
  #          Similar to wg1, full tunnel (0.0.0.0/0). Selected source IPs
  #          are sent to it via policy routing managed by the `vpn-home`
  #          utility (see vpn-home.nix).
  #
  # Integration:
  # - Configurations stored in SOPS encrypted secrets (vpn.conf / vpn.fast.conf / vpn.home.conf)
  # - Automatically started/stopped with PPPoE connection
  # - Policy routing ensures VPN traffic bypasses the tunnels themselves
  # 
  # Manual control:
  #   systemctl start wg-quick-wg0    # Start secure VPN
  #   systemctl start wg-quick-wg1    # Start fast VPN
  #   systemctl start wg-quick-wg2    # Start home VPN
  # ===========================================================================

  # --------------------------------------------------------------------------
  # wg0 — secure profile (default tunnel for all LAN traffic)
  # --------------------------------------------------------------------------
  networking.wg-quick.interfaces.wg0 = {
    # Configuration file is encrypted with SOPS
    # Contains: private key, peer public key, endpoint, allowed IPs
    configFile = config.sops.secrets."vpn.conf".path;
    
    # Don't start automatically at boot
    # VPN is started by PPP ip-up script (after WAN is up)
    autostart = false;
  };

  # --------------------------------------------------------------------------
  # wg1 — fast profile (used only by devices routed via `vpn-fast`)
  # --------------------------------------------------------------------------
  # wg1 reads the raw SOPS-decrypted config directly. The config almost
  # certainly has `AllowedIPs = 0.0.0.0/0` which makes wg-quick try to hijack
  # the default route — installing a `not fwmark <mark> lookup <mark>` rule
  # and a second `suppress_prefixlength 0` rule. That would break every other
  # device on the LAN because all unmatched traffic would be pulled into wg1.
  #
  # Instead of rewriting the config (fragile, fights with SOPS), we let
  # wg-quick do its thing and then surgically undo ONLY the rules/routes it
  # added for wg1 — see vpn-fast.nix where the cleanup runs as an
  # ExecStartPost on wg-quick-wg1.service. After cleanup, wg1 is a dormant
  # tunnel that carries traffic only for source IPs explicitly policy-routed
  # into table 201 by the `vpn-fast` CLI.
  networking.wg-quick.interfaces.wg1 = {
    configFile = config.sops.secrets."vpn.fast.conf".path;
    autostart = false;
  };

  # --------------------------------------------------------------------------
  # wg2 — home profile (used only by devices routed via `vpn-home`)
  # --------------------------------------------------------------------------
  # wg2 works exactly like wg1. We surgical undo wg-quick's rules via ExecStartPost
  # in vpn-home.nix. The `vpn-home` CLI manages sending traffic explicitly into
  # table 202.
  networking.wg-quick.interfaces.wg2 = {
    configFile = config.sops.secrets."vpn.home.conf".path;
    autostart = false;
  };

  # SOPS secrets for WireGuard configurations
  # Keeps VPN credentials secure (root-only, mode 0400)
  sops.secrets."vpn.conf" = { };
  sops.secrets."vpn.fast.conf" = { };
  sops.secrets."vpn.home.conf" = { };

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
      # Also (re)start the fast and home tunnels. Neutralisation of their
      # default routes is handled automatically by their ExecStartPost hooks.
      ${pkgs.systemd}/bin/systemctl restart wg-quick-wg1.service
      ${pkgs.systemd}/bin/systemctl restart wg-quick-wg2.service
    '';
  };

  # Stop WireGuard when PPP goes down
  environment.etc."ppp/ip-down.d/01-wireguard" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      # Stop VPNs when WAN is down (no point keeping them up)
      ${pkgs.systemd}/bin/systemctl stop wg-quick-wg0.service
      ${pkgs.systemd}/bin/systemctl stop wg-quick-wg1.service
      ${pkgs.systemd}/bin/systemctl stop wg-quick-wg2.service
    '';
  };
}
