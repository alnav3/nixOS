{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # VPN Fast-Profile Switcher (per-device)
  # ===========================================================================
  # This module provides per-device switching between the two WireGuard
  # tunnels configured in wireguard.nix:
  #
  #   wg0 — secure profile (vpn.conf)        — default for all LAN traffic
  #   wg1 — fast profile   (vpn.fast.conf)   — opt-in per source IP
  #
  # Purpose:
  # - Let specific LAN devices use the faster/less-loaded provider endpoint
  #   while the rest of the LAN stays on the secure tunnel.
  # - Supports temporary (timed) and permanent opt-in, mirroring vpn-bypass.
  #
  # Usage:
  #   vpn-fast <IP> [duration]     Route <IP> via wg1 for the given duration
  #                                (defaults to 5m, accepts 30s/2h/7d etc.)
  #   vpn-fast <IP> permanent      Persist across reboots
  #   vpn-fast <IP> off            Revert <IP> to the secure wg0 tunnel
  #   vpn-fast list                Show currently active fast-VPN devices
  #
  # Technical implementation:
  # 1. nftables set  (vpn_fast)            — matches traffic in the forward
  #                                           chain so it is accepted to wg1.
  # 2. Policy routing (table 201 "fastvpn") — default route via wg1. Per-IP
  #                                           rules send matched sources there.
  # 3. Persistent storage (/var/lib/vpn-fast/permanent) — restored on boot.
  # 4. Lifecycle hooks on wg-quick-wg1.service — (re)populate table 201 on
  #                                              startup, flush on stop.
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Routing table definition
  # ---------------------------------------------------------------------------
  # `ip rule`/`ip route` accept either numeric IDs or names declared here.
  # We pick 201 to stay well clear of wg-quick's auto-allocated tables (which
  # start in the low thousands) and the main/local/default tables (253/254/255).
  environment.etc."iproute2/rt_tables.d/vpn-fast.conf".text = ''
    201 fastvpn
  '';

  # ---------------------------------------------------------------------------
  # Persistent state directory
  # ---------------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    "d /var/lib/vpn-fast 0700 root root -"
    "f /var/lib/vpn-fast/permanent 0600 root root -"
  ];

  # ---------------------------------------------------------------------------
  # wg1 lifecycle hooks: neutralise wg-quick's default-route hijack,
  # then populate our own table 201.
  # ---------------------------------------------------------------------------
  # When wg1 comes up, wg-quick (because the conf has AllowedIPs=0.0.0.0/0)
  # installs these on its own:
  #
  #   ip rule add not fwmark <MARK> lookup <MARK>           (prio auto)
  #   ip rule add table main suppress_prefixlength 0         (prio auto)
  #   ip route add 0.0.0.0/0 dev wg1 table <MARK>
  #
  # Those two rules together route ALL unmarked traffic on the router into
  # wg1 — including traffic that was supposed to go through wg0 — which
  # blackholes LAN internet. We cannot prevent wg-quick from adding them
  # (the SOPS-encrypted conf would need Table=off and rewriting it is
  # fragile), so instead we run RIGHT AFTER wg-quick finishes and remove
  # exactly those entries. wg0's equivalent rules are kept intact.
  systemd.services.wg-quick-wg1 = {
    serviceConfig = {
      ExecStartPost = [
        "${pkgs.writeShellScript "vpn-fast-up" ''
          set -eu
          PATH=${lib.makeBinPath [ pkgs.iproute2 pkgs.nftables pkgs.wireguard-tools pkgs.gawk pkgs.coreutils pkgs.gnugrep ]}

          # --------------------------------------------------------------
          # 1. Identify wg1's fwmark (wg-quick uses it as the table ID too)
          # --------------------------------------------------------------
          # `wg show wg1 fwmark` prints hex like 0xca6d; strip the 0x and
          # convert to decimal. Table ID == fwmark for wg-quick.
          MARK_HEX=$(wg show wg1 fwmark)
          if [ -z "$MARK_HEX" ] || [ "$MARK_HEX" = "off" ]; then
            echo "vpn-fast: wg1 has no fwmark — nothing to undo"
            MARK=""
          else
            MARK=$((MARK_HEX))
            echo "vpn-fast: wg1 fwmark=$MARK — removing wg-quick's default-route hijack"
          fi

          if [ -n "$MARK" ]; then
            # ------------------------------------------------------------
            # 2. Delete the `not fwmark <MARK> lookup <MARK>` rule.
            #    This is the one that steals everyone's traffic.
            # ------------------------------------------------------------
            ip -4 rule del not fwmark "$MARK" lookup "$MARK" 2>/dev/null || true

            # ------------------------------------------------------------
            # 3. Delete wg-quick's suppress_prefixlength rule for wg1.
            #
            #    wg-quick adds `ip rule add table main suppress_prefixlength 0`
            #    without an explicit priority, so the kernel assigns the
            #    next-available LOW priority number (rules are walked in
            #    ascending priority order). Startup sequence:
            #
            #      wg0 up  →  prio 32765 fwmark, prio 32764 suppress
            #      wg1 up  →  prio 32763 fwmark, prio 32762 suppress
            #
            #    So wg1's suppress rule has the LOWEST priority number
            #    among all suppress_prefixlength rules. We delete that
            #    one and leave wg0's untouched.
            # ------------------------------------------------------------
            SUPP_COUNT=$(ip -4 rule show | awk '/suppress_prefixlength 0/' | wc -l)
            if [ "$SUPP_COUNT" -gt 1 ]; then
              LOW_PRIO=$(ip -4 rule show \
                | awk -F: '/suppress_prefixlength 0/ { print $1+0 }' \
                | sort -n | head -1)
              ip -4 rule del priority "$LOW_PRIO" 2>/dev/null || true
              echo "vpn-fast: removed wg1's suppress_prefixlength rule at priority $LOW_PRIO"
            fi

            # ------------------------------------------------------------
            # 4. Flush the table wg-quick created for wg1. We won't use
            #    it — our per-device routing lives in table 201.
            # ------------------------------------------------------------
            ip -4 route flush table "$MARK" 2>/dev/null || true

            # Clear wg1's fwmark — we don't need it any more, and
            # leaving it set is harmless but noisy.
            wg set wg1 fwmark 0 2>/dev/null || true
          fi

          # --------------------------------------------------------------
          # 5. Install OUR default route for wg1 into table 201.
          # --------------------------------------------------------------
          ip -4 route replace default dev wg1 table 201
          ip -4 route flush cache

          # Route other subnets via fastvpn by default (priority 50 so it's before wg0 rules)
          ip -4 rule add iif brguest table fastvpn priority 50 2>/dev/null || true
          ip -4 rule add iif briot table fastvpn priority 50 2>/dev/null || true
          ip -4 rule add iif brhomelab table fastvpn priority 50 2>/dev/null || true
          
          # For brdirect, we route it to fastvpn, BUT we must exclude OpenVPN (10.71.73.10 and 10.8.0.0/24)
          # so OpenVPN continues to use wg0. We do this by routing OpenVPN explicitly to wg0's table
          # at a higher priority (49) than the brdirect rule (50).
          WG0_MARK=$(wg show wg0 fwmark 2>/dev/null || echo "off")
          if [ -n "$WG0_MARK" ] && [ "$WG0_MARK" != "off" ]; then
            WG0_TABLE=$((WG0_MARK))
            ip -4 rule add from 10.71.73.10 table "$WG0_TABLE" priority 49 2>/dev/null || true
            ip -4 rule add from 10.8.0.0/24 table "$WG0_TABLE" priority 49 2>/dev/null || true
          fi
          ip -4 rule add iif brdirect table fastvpn priority 50 2>/dev/null || true


          # --------------------------------------------------------------
          # 6. Re-apply any permanent per-IP policy rules.
          # --------------------------------------------------------------
          FILE="/var/lib/vpn-fast/permanent"
          if [ -s "$FILE" ]; then
            # Priority must beat wg0's fwmark/suppress rules so matched
            # sources are pulled into table 201 before wg0 claims them.
            WG_LOWEST=$(ip -4 rule show \
              | awk -F: '/suppress_prefixlength|fwmark/{print $1+0}' \
              | sort -n | head -1)
            if [ -n "$WG_LOWEST" ] && [ "$WG_LOWEST" -gt 10 ]; then
              PRIO=$(( WG_LOWEST - 9 ))
            else
              PRIO=51
            fi

            while IFS= read -r ip || [ -n "$ip" ]; do
              [ -z "$ip" ] && continue
              nft add element inet filter vpn_fast "{ $ip }" 2>/dev/null || true
              ip -4 rule del from "$ip" table fastvpn priority "$PRIO" 2>/dev/null || true
              ip -4 rule add from "$ip" table fastvpn priority "$PRIO"
            done < "$FILE"
            ip -4 route flush cache
            echo "vpn-fast: restored $(wc -l < "$FILE") permanent entries at priority $PRIO"
          fi
        ''}"
      ];
      ExecStopPost = [
        "${pkgs.writeShellScript "vpn-fast-down" ''
          set -eu
          PATH=${lib.makeBinPath [ pkgs.iproute2 pkgs.nftables pkgs.coreutils pkgs.gawk ]}

          # Remove every `from <ip> lookup fastvpn` rule. Loop because we
          # can't enumerate priorities up-front reliably.
          while ip -4 rule show | awk '/lookup fastvpn/ {found=1} END { exit !found }'; do
            RULE=$(ip -4 rule show | awk '/lookup fastvpn/ { print; exit }')
            PRIO=$(echo "$RULE" | awk -F: '{print $1+0}')
            SRC=$(echo "$RULE"  | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}')
            IIF=$(echo "$RULE"  | awk '{for(i=1;i<=NF;i++) if($i=="iif") print $(i+1)}')
            if [ -n "$SRC" ]; then
              ip -4 rule del from "$SRC" table fastvpn priority "$PRIO" 2>/dev/null || break
            elif [ -n "$IIF" ]; then
              ip -4 rule del iif "$IIF" table fastvpn priority "$PRIO" 2>/dev/null || break
            else
              # Fallback if neither from nor iif matches
              ip -4 rule del priority "$PRIO" 2>/dev/null || break
            fi
          done

          # Cleanup OpenVPN bypass rules (priority 49)
          ip -4 rule del priority 49 2>/dev/null || true
          ip -4 rule del priority 49 2>/dev/null || true


          # Flush table 201 and any scheduled cleanup timers.
          ip -4 route flush table 201 2>/dev/null || true
          ip -4 route flush cache

          # Flush nftables set — membership is moot while wg1 is down.
          nft flush set inet filter vpn_fast 2>/dev/null || true
        ''}"
      ];
    };
  };

  # ---------------------------------------------------------------------------
  # vpn-fast CLI
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    (pkgs.writeShellScriptBin "vpn-fast" ''
      set -eu
      PATH=${lib.makeBinPath [ pkgs.iproute2 pkgs.nftables pkgs.gawk pkgs.coreutils pkgs.gnused pkgs.gnugrep pkgs.systemd ]}

      IP=''${1:-}
      DURATION=''${2:-5m}
      UNIT="vpn-fast-$(echo "$IP" | tr '.' '-')"
      PERM_FILE="/var/lib/vpn-fast/permanent"

      usage() {
        cat <<'EOF'
      Usage:
        vpn-fast <IP> [duration]   Route <IP> via fast VPN (default 5m)
        vpn-fast <IP> permanent    Route <IP> via fast VPN across reboots
        vpn-fast <IP> off          Revert <IP> to secure VPN
        vpn-fast list              Show current fast-VPN devices

      Duration format: 30s, 5m, 2h, 1d — or plain seconds.
      EOF
      }

      parse_secs() {
        case "$1" in
          *d) echo $(( ''${1%d} * 86400 )) ;;
          *h) echo $(( ''${1%h} * 3600 )) ;;
          *m) echo $(( ''${1%m} * 60 )) ;;
          *s) echo "''${1%s}" ;;
          *) echo "$1" ;;
        esac
      }

      # Priority: one less than vpn-bypass uses so bypass still wins if both
      # are set for the same IP (bypass → no VPN, fast → fast VPN).
      fast_prio() {
        WG=$(ip rule show | awk -F: '/suppress_prefixlength|fwmark/{print $1+0}' | sort -n | head -1)
        if [ -n "$WG" ] && [ "$WG" -gt 10 ]; then
          echo $(( WG - 9 ))
        else
          echo 51
        fi
      }

      if [ -z "$IP" ]; then
        usage
        exit 1
      fi

      PRIO=$(fast_prio)

      # --- list ----------------------------------------------------------------
      if [ "$IP" = "list" ]; then
        echo "== nftables set vpn_fast =="
        nft list set inet filter vpn_fast 2>/dev/null || echo "(wg1 not running — set not loaded)"
        echo ""
        echo "== Policy routing rules (priority $PRIO, table fastvpn) =="
        ip rule show | awk '/lookup fastvpn/'
        echo ""
        echo "== Permanent entries =="
        if [ -s "$PERM_FILE" ]; then
          cat "$PERM_FILE"
        else
          echo "(none)"
        fi
        echo ""
        echo "== wg1 status =="
        systemctl is-active wg-quick-wg1.service || true
        exit 0
      fi

      # Basic IP sanity check (IPv4 only, matches vpn-bypass behaviour)
      case "$IP" in
        *.*.*.*) ;;
        *) echo "Error: '$IP' does not look like an IPv4 address" >&2; exit 1 ;;
      esac

      # --- off -----------------------------------------------------------------
      if [ "$DURATION" = "off" ]; then
        nft delete element inet filter vpn_fast "{ $IP }" 2>/dev/null || true
        ip rule del from "$IP" table fastvpn priority "$PRIO" 2>/dev/null || true
        ip route flush cache
        systemctl stop "$UNIT.service" 2>/dev/null || true
        sed -i "/^$(echo "$IP" | sed 's/\./\\./g')$/d" "$PERM_FILE" 2>/dev/null || true
        echo "Fast VPN disabled for $IP — traffic now flows through secure VPN (wg0)"
        exit 0
      fi

      # Require wg1 to actually be up before we route to it
      if ! systemctl is-active --quiet wg-quick-wg1.service; then
        echo "Error: wg-quick-wg1.service is not running. Start it first:" >&2
        echo "  systemctl start wg-quick-wg1" >&2
        exit 1
      fi

      # --- add rule (common to temporary and permanent) ------------------------
      ip rule del from "$IP" table fastvpn priority "$PRIO" 2>/dev/null || true
      ip rule add from "$IP" table fastvpn priority "$PRIO"
      ip route flush cache

      # --- permanent -----------------------------------------------------------
      if [ "$DURATION" = "permanent" ] || [ "$DURATION" = "perm" ]; then
        nft add element inet filter vpn_fast "{ $IP }"
        grep -qxF "$IP" "$PERM_FILE" 2>/dev/null || echo "$IP" >> "$PERM_FILE"
        # Clean up any pending timer from a previous temporary run
        systemctl stop "$UNIT.service" 2>/dev/null || true
        echo "Fast VPN permanently active for $IP — remove with: vpn-fast $IP off"
        exit 0
      fi

      # --- temporary (timed) ---------------------------------------------------
      SECS=$(parse_secs "$DURATION")
      nft add element inet filter vpn_fast "{ $IP timeout $DURATION }"

      # Schedule removal of the routing rule when the set entry expires.
      # We stop any previous timer first so repeated invocations reset the clock.
      systemctl stop "$UNIT.service" 2>/dev/null || true
      systemd-run \
        --on-active="''${SECS}s" \
        --unit="$UNIT" \
        --description="Revert VPN fast routing for $IP" \
        ${pkgs.iproute2}/bin/ip rule del from "$IP" table fastvpn priority "$PRIO"

      echo "Fast VPN active for $IP — expires in $DURATION (then reverts to wg0)"
    '')
  ];
}
