{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # WAN Configuration: PPPoE + Dynamic DNS
  # ===========================================================================
  # This module configures the WAN (internet) connection and dynamic DNS.
  # 
  # Components:
  # 1. PPPoE: DSL connection using PPP over Ethernet
  # 2. DuckDNS: Dynamic DNS for personal subdomain
  # 3. Cloudflare DDNS: Dynamic DNS for custom domain (alnav.dev)
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # SOPS Secrets
  # ---------------------------------------------------------------------------
  # Credentials stored encrypted, decrypted at runtime
  sops.secrets."duckdns.env" = { };      # DuckDNS API token
  sops.secrets."cloudflare.env" = { };   # Cloudflare API token
  
  # PAP authentication for PPPoE
  sops.secrets."pap-secrets" = {
    path = "/etc/ppp/pap-secrets";  # Standard PPP secrets location
    owner = "root";
    group = "root";
    mode = "0600";                  # Strict permissions (root only)
  };

  # ---------------------------------------------------------------------------
  # PPPoE Configuration
  # ---------------------------------------------------------------------------
  # Point-to-Point Protocol over Ethernet for DSL connection
  # Creates ppp0 interface when connection is established
  services.pppd = {
    enable = true;
    peers.wan = {
      autostart = true;  # Start at boot
      enable = true;
      config = ''
        # PPPoE plugin and physical interface
        plugin pppoe.so ens18.20
        
        # ISP username (from pap-secrets file)
        name "611835311@digi"
        
        # Authentication settings
        auth                   # Require authentication
        refuse-chap            # Refuse CHAP authentication
        refuse-mschap          # Refuse MS-CHAPv1
        refuse-mschap-v2       # Refuse MS-CHAPv2
        refuse-eap             # Refuse EAP
        debug                  # Enable debug logging
        noipdefault            # Don't assume IP 0.0.0.0
        defaultroute           # Set ppp0 as default gateway
        hide-password          # Don't show password in logs
        noauth                 # Don't authenticate peer (ISP)
        
        # Connection persistence
        persist                # Keep trying to reconnect
        maxfail 0              # Retry forever
        holdoff 5              # Wait 5s between retries
        
        # MTU/MRU settings for PPPoE
        # Ethernet MTU is 1500, PPPoE overhead is 8 bytes
        mtu 1492               # Maximum Transmission Unit
        mru 1492               # Maximum Receive Unit
        
        # Keep-alive (detect dead connections)
        lcp-echo-interval 20   # Send echo every 20s
        lcp-echo-failure 3     # Reconnect after 3 missed echos (60s)
        
        # Interface name
        ifname ppp0            # Always use ppp0 (predictable name)
      '';
    };
  };

  # Ensure VLAN interface is up before PPP starts
  # PPPoE requires the underlying VLAN to exist and be UP
  systemd.services."pppd-wan".preStart = ''
    ${pkgs.iproute2}/bin/ip link set ens18 up 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip link set ens18.20 up 2>/dev/null || true
  '';

  # ---------------------------------------------------------------------------
  # DuckDNS Dynamic DNS
  # ---------------------------------------------------------------------------
  # Updates alnav.duckdns.org to point to current WAN IP
  # Useful for quick access without custom domain
  systemd.services.duckdns = {
    description = "DuckDNS dynamic DNS update";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."duckdns.env".path;
      ExecStart = pkgs.writeShellScript "duckdns-update" ''
        # Query DuckDNS API to update IP
        # --interface ppp0 ensures we get WAN IP, not VPN IP
        RESULT=$(${pkgs.curl}/bin/curl -sf --interface ppp0 \
          "https://www.duckdns.org/update?domains=alnav&token=$DUCKDNS_TOKEN&ip=")
        echo "DuckDNS: $RESULT"
        
        # Check if update succeeded
        [ "$RESULT" = "OK" ] || { echo "DuckDNS update failed: $RESULT"; exit 1; }
      '';
    };
  };

  # Run DuckDNS update every 5 minutes
  systemd.timers.duckdns = {
    description = "DuckDNS update timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";        # First update 1 min after boot
      OnUnitActiveSec = "5min";  # Then every 5 minutes
    };
  };

  # ---------------------------------------------------------------------------
  # Cloudflare Dynamic DNS
  # ---------------------------------------------------------------------------
  # Updates alnav.dev A record to point to current WAN IP
  # More professional than DuckDNS, custom domain
  systemd.services.cloudflare-ddns = {
    description = "Cloudflare dynamic DNS update for alnav.dev";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."cloudflare.env".path;
      ExecStart = pkgs.writeShellScript "cloudflare-ddns-update" ''
        CURL=${pkgs.curl}/bin/curl
        JQ=${pkgs.jq}/bin/jq
        CF="https://api.cloudflare.com/client/v4"
        
        # Get current WAN IP via ifconfig.me
        # --interface ppp0 ensures we get real WAN IP
        WAN_IP=$($CURL -sf --interface ppp0 https://ifconfig.me)
        [ -z "$WAN_IP" ] && { echo "ERROR: could not get WAN IP"; exit 1; }
        echo "WAN IP: $WAN_IP"
        
        # Get Cloudflare Zone ID for alnav.dev
        ZONE_ID=$($CURL -sf \
          -H "Authorization: Bearer $CLOUDFLARE_DNS_API_TOKEN" \
          -H "Content-Type: application/json" \
          "$CF/zones?name=alnav.dev" \
          | $JQ -r '.result[0].id')
        [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ] && { echo "ERROR: zone alnav.dev not found"; exit 1; }
        echo "Zone ID: $ZONE_ID"
        
        # Function to update a DNS record
        update_record() {
          FQDN=$1
          
          # Get DNS record ID for the FQDN
          RECORD_ID=$($CURL -sf \
            -H "Authorization: Bearer $CLOUDFLARE_DNS_API_TOKEN" \
            -H "Content-Type: application/json" \
            "$CF/zones/$ZONE_ID/dns_records?type=A&name=$FQDN" \
            | $JQ -r '.result[0].id')
          
          if [ -z "$RECORD_ID" ] || [ "$RECORD_ID" = "null" ]; then
            echo "SKIP: no A record found for $FQDN"
            return 0
          fi
          
          # Update the A record with new IP
          OK=$($CURL -sf -X PATCH \
            -H "Authorization: Bearer $CLOUDFLARE_DNS_API_TOKEN" \
            -H "Content-Type: application/json" \
            "$CF/zones/$ZONE_ID/dns_records/$RECORD_ID" \
            --data "{\"type\":\"A\",\"content\":\"$WAN_IP\"}" \
            | $JQ -r '.success')
          
          echo "$FQDN → $WAN_IP : $OK"
          [ "$OK" = "true" ]
        }
        
        # Update the main domain record
        update_record "alnav.dev"
      '';
    };
  };

  # Run Cloudflare DDNS update every 5 minutes
  systemd.timers.cloudflare-ddns = {
    description = "Cloudflare DDNS update timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";        # First update 1 min after boot
      OnUnitActiveSec = "5min";  # Then every 5 minutes
    };
  };
}
