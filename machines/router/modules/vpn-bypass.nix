{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # VPN Bypass System
  # ===========================================================================
  # This module provides selective VPN bypass functionality.
  # 
  # Purpose:
  # - Allow specific IPs to bypass WireGuard VPN and use direct WAN
  # - Useful for services that block VPN IPs (banking, streaming, etc.)
  # - Supports temporary (timed) and permanent bypass
  # 
  # Usage:
  #   vpn-bypass <IP> [duration]  # Add temporary bypass
  #   vpn-bypass <IP> permanent   # Add permanent bypass
  #   vpn-bypass <IP> off         # Remove bypass
  #   vpn-bypass list             # Show current bypasses
  # 
  # Technical implementation:
  # 1. nftables set (vpn_bypass): Allows matching traffic in firewall
  # 2. Policy routing rules: Forces bypass traffic to use main table (ppp0)
  # 3. Persistent storage: Survives reboots
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Create Required Directories
  # ---------------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    # Directory for VPN bypass state
    "d /var/lib/vpn-bypass 0700 root root -"
    # File for permanent bypass entries (one IP per line)
    "f /var/lib/vpn-bypass/permanent 0600 root root -"
  ];

  # ---------------------------------------------------------------------------
  # VPN Bypass Restore Service
  # ---------------------------------------------------------------------------
  # Restores permanent bypass entries after reboot
  # Reads /var/lib/vpn-bypass/permanent and re-applies rules
  systemd.services.vpn-bypass-restore = {
    description = "Restore permanent VPN bypass rules";
    after = [ "nftables.service" "network-online.target" "wg-quick-wg0.service" ];
    wants = [ "network-online.target" "wg-quick-wg0.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.nftables pkgs.iproute2 pkgs.gawk ];
    script = ''
      FILE="/var/lib/vpn-bypass/permanent"
      [ -f "$FILE" ] || exit 0
      
      # Determine bypass priority (must be higher than wg-quick rules)
      # wg-quick adds rules at priority 51-52, we use 10 less (higher priority)
      WG_LOWEST=$(ip rule show | awk -F: '/suppress_prefixlength|fwmark/{print $1+0}' | sort -n | head -1)
      if [ -n "$WG_LOWEST" ] && [ "$WG_LOWEST" -gt 10 ]; then
        PRIO=$(( WG_LOWEST - 10 ))
      else
        PRIO=50
      fi
      echo "Using bypass priority $PRIO (wg-quick lowest: $WG_LOWEST)"
      
      # Restore each permanent bypass entry
      while IFS= read -r ip || [ -n "$ip" ]; do
        [ -z "$ip" ] && continue
        
        # Add to nftables set (no timeout = permanent)
        nft add element inet filter vpn_bypass "{ $ip }" 2>/dev/null || true
        
        # Add policy routing rule (forces main table = ppp0)
        ip rule del from "$ip" table main priority "$PRIO" 2>/dev/null || true
        ip rule add from "$ip" table main priority "$PRIO"
        
        echo "Restored permanent bypass for $ip at priority $PRIO"
      done < "$FILE"
      
      # Flush routing cache to apply changes immediately
      ip route flush cache
      echo "Restored permanent brdirect bypass (10.71.73.0/24) at priority $PRIO"
    '';
  };

  # ---------------------------------------------------------------------------
  # VPN Bypass Command-Line Tool
  # ---------------------------------------------------------------------------
  # User-friendly wrapper for managing VPN bypass
  # Handles nftables sets, policy routing, and persistence
  environment.systemPackages = with pkgs; [
    (pkgs.writeShellScriptBin "vpn-bypass" ''
      IP=$1
      DURATION=''${2:-5m}
      UNIT="vpn-bypass-$(echo "$IP" | tr '.' '-')"
      
      # Parse duration string (5m, 2h, 30s) to seconds
      parse_secs() {
        case "$1" in
          *h) echo $(( ''${1%h} * 3600 )) ;;
          *m) echo $(( ''${1%m} * 60 )) ;;
          *s) echo "''${1%s}" ;;
          *) echo "$1" ;;
        esac
      }
      
      # Calculate bypass priority (higher than wg-quick)
      # wg-quick uses fwmark and suppress_prefixlength rules around priority 51-52
      # We need priority to be lower number (processed first) to catch traffic before wg-quick
      bypass_prio() {
        WG=$(ip rule show | awk -F: '/suppress_prefixlength|fwmark/{print $1+0}' | sort -n | head -1)
        if [ -n "$WG" ] && [ "$WG" -gt 10 ]; then
          echo $(( WG - 10 ))
        else
          echo 50
        fi
      }
      
      PRIO=$(bypass_prio)
      
      # Show usage if no IP provided
      if [ -z "$IP" ]; then
        echo "Usage: vpn-bypass <IP> [duration|off]"
        echo " vpn-bypass list"
        exit 1
      fi
      
      # List current bypasses
      if [ "$IP" = "list" ]; then
        nft list set inet filter vpn_bypass
        echo ""
        echo "Active routing rules (bypass priority: $PRIO):"
        ip rule show | awk -F: -v p="$PRIO" '$1+0 == p'
        exit 0
      fi
      
      # Remove bypass
      if [ "$DURATION" = "off" ]; then
        # Remove from nftables set
        nft delete element inet filter vpn_bypass "{ $IP }" 2>/dev/null || true
        # Remove policy routing rule
        ip rule del from "$IP" table main priority "$PRIO" 2>/dev/null || true
        # Stop cleanup timer if it exists
        systemctl stop "$UNIT.service" 2>/dev/null || true
        # Remove from permanent file
        sed -i "/^$(echo "$IP" | sed 's/\./\\./g')$/d" /var/lib/vpn-bypass/permanent 2>/dev/null || true
        echo "Bypass removed for $IP"
        exit 0
      fi
      
      # Add policy routing rule (forces main table = ppp0)
      ip rule del from "$IP" table main priority "$PRIO" 2>/dev/null || true
      ip rule add from "$IP" table main priority "$PRIO"
      
      # Permanent bypass
      if [ "$DURATION" = "permanent" ] || [ "$DURATION" = "perm" ]; then
        # Add to nftables set (no timeout)
        nft add element inet filter vpn_bypass "{ $IP }"
        # Save to permanent file (survives reboots)
        grep -qxF "$IP" /var/lib/vpn-bypass/permanent 2>/dev/null || echo "$IP" >> /var/lib/vpn-bypass/permanent
        echo "Bypass permanently active for $IP — remove with: vpn-bypass $IP off"
        exit 0
      fi
      
      # Temporary (timed) bypass
      SECS=$(parse_secs "$DURATION")
      # Add to nftables set with timeout
      nft add element inet filter vpn_bypass "{ $IP timeout $DURATION }"
      
      # Schedule automatic cleanup of routing rule
      # systemd-run creates a one-shot timer to remove the rule
      ${pkgs.systemd}/bin/systemd-run \
        --on-active="''${SECS}s" \
        --unit="$UNIT" \
        --description="Remove VPN bypass routing for $IP" \
        ${pkgs.iproute2}/bin/ip rule del from "$IP" table main priority "$PRIO"
      
      echo "Bypass active for $IP — expires in $DURATION"
    '')
  ];
}
