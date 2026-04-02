{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # OpenVPN Server — remote LAN access from outside
  #
  # PKI is generated on first boot by openvpn-home-pki.service.
  # After that, grab /var/lib/openvpn/home/client.ovpn, set your WAN IP in it,
  # and import it in any OpenVPN client (desktop/mobile).
  #
  # Users file (/var/lib/openvpn/home/users) is runtime-managed — edit and
  # run `systemctl restart openvpn-home` to pick up changes. Format: user:pass
  #
  # Access control:
  # user1 → gets static IP 10.8.0.2 (CCD) + LAN route pushed → can reach brlan
  # other users → dynamic pool IP, no route push → internet only (via WireGuard)
  # ===========================================================================
  
  # OpenVPN server state directory + initial users file (only written if missing)
  systemd.tmpfiles.rules = [
    "d /var/lib/openvpn/home 0700 root root -"
    "f /var/lib/openvpn/home/users 0600 root root - user1:Rand0mP4ss2024"
    "d /var/log/openvpn 0755 root root -"
  ];

  # Auth script and per-user CCD (Client Config Directory) — Nix-managed, read-only
  environment.etc = {
    "openvpn/home/auth.sh" = {
      mode = "0755";
      text = ''
        #!/bin/sh
        # Called by OpenVPN with a tmpfile: line 1 = username, line 2 = password
        # Uses only shell builtins — OpenVPN runs scripts with a stripped PATH
        USERS="/var/lib/openvpn/home/users"
        { IFS= read -r u; IFS= read -r p; } < "$1"
        # || [ -n "$fu" ] handles files without a trailing newline
        while IFS=: read -r fu fp || [ -n "$fu" ]; do
          [ "$fu" = "$u" ] && [ "$fp" = "$p" ] && exit 0
        done < "$USERS"
        exit 1
      '';
    };
    # Admin users (10.8.0.2-9) — nftables allows this range to reach brlan
    "openvpn/home/ccd/user1" = {
      mode = "0644";
      text = ''
        ifconfig-push 10.8.0.2 255.255.255.0
        push "route 10.71.71.0 255.255.255.0"
      '';
    };
    # Restricted users (10.8.0.10+) — internet only, nftables blocks brlan
    "openvpn/home/ccd/user2" = {
      mode = "0644";
      text = ''
        ifconfig-push 10.8.0.10 255.255.255.0
      '';
    };
  };

  # Generate PKI on first boot (skips if ca.crt already exists)
  systemd.services.openvpn-home-pki = {
    description = "Generate OpenVPN home server PKI (first boot only)";
    before = [ "openvpn-home.service" ];
    wantedBy = [ "openvpn-home.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "openvpn/home";
      StateDirectoryMode = "0700";
    };
    path = [ pkgs.openssl pkgs.openvpn ];
    script = ''
      PKI="/var/lib/openvpn/home/pki"
      [ -f "$PKI/ca.crt" ] && exit 0 # already initialised
      mkdir -p "$PKI"
      chmod 700 "$PKI"
      # Certificate Authority
      openssl genrsa -out "$PKI/ca.key" 2048
      openssl req -new -x509 -days 3650 \
        -key "$PKI/ca.key" -out "$PKI/ca.crt" \
        -subj "/CN=HomeRouter-CA"
      # Server key + certificate signed by the CA (v3 extensions required by modern OpenSSL)
      openssl genrsa -out "$PKI/server.key" 2048
      openssl req -new \
        -key "$PKI/server.key" -out "$PKI/server.csr" \
        -subj "/CN=HomeRouter-VPN"
      cat > "$PKI/server_ext.cnf" << 'EXTEOF'
[server_ext]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
EXTEOF
      openssl x509 -req -days 3650 \
        -in "$PKI/server.csr" \
        -CA "$PKI/ca.crt" -CAkey "$PKI/ca.key" -CAcreateserial \
        -out "$PKI/server.crt" \
        -extfile "$PKI/server_ext.cnf" \
        -extensions server_ext
      # Diffie-Hellman parameters
      openssl dhparam -out "$PKI/dh.pem" 2048
      # TLS auth key — blocks unauthenticated handshake attempts
      openvpn --genkey secret "$PKI/ta.key"
      # Client config template — copy, fill in WAN IP, import in OpenVPN client
      CA_CERT=$(cat "$PKI/ca.crt")
      TA_KEY=$(cat "$PKI/ta.key")
      cat > /var/lib/openvpn/home/client.ovpn << OVPN
      client
      dev tun
      proto udp
      remote REPLACE_WITH_YOUR_WAN_IP 1194
      resolv-retry infinite
      nobind
      persist-key
      persist-tun
      remote-cert-tls server
      auth-user-pass
      cipher AES-256-GCM
      auth SHA256
      key-direction 1
      verb 3
      <ca>
      $CA_CERT
      </ca>
      <tls-auth>
      $TA_KEY
      </tls-auth>
      OVPN
      chmod 600 "$PKI/ca.key" "$PKI/server.key" "$PKI/ta.key"
      chmod 644 /var/lib/openvpn/home/client.ovpn
    '';
  };

  services.openvpn.servers.home = {
    autoStart = true;
    updateResolvConf = false;
    config = ''
      port 1194
      proto udp
      dev tun0
      ca /var/lib/openvpn/home/pki/ca.crt
      cert /var/lib/openvpn/home/pki/server.crt
      key /var/lib/openvpn/home/pki/server.key
      dh /var/lib/openvpn/home/pki/dh.pem
      tls-auth /var/lib/openvpn/home/pki/ta.key 0
      topology subnet
      server 10.8.0.0 255.255.255.0
      client-config-dir /etc/openvpn/home/ccd
      ifconfig-pool-persist /var/lib/openvpn/home/ipp.txt
      # Username/password auth — no client certificate required
      auth-user-pass-verify /etc/openvpn/home/auth.sh via-file
      username-as-common-name
      verify-client-cert none
      script-security 2
      keepalive 10 120
      cipher AES-256-GCM
      auth SHA256
      persist-key
      persist-tun
      # Push DNS + search domain so clients resolve .home and unqualified names
      push "dhcp-option DNS 10.71.71.1"
      push "dhcp-option DOMAIN home"
      push "dhcp-option DOMAIN-SEARCH home"
      status /var/log/openvpn/home-status.log
      verb 3
    '';
  };

  # Log rotation for OpenVPN status file
  services.logrotate = {
    enable = true;
    settings = {
      "/var/log/openvpn/home-status.log" = {
        frequency = "daily";
        rotate = 7;
        compress = true;
        missingok = true;
        notifempty = true;
        # OpenVPN rewrites the status file atomically — no signal needed
        copytruncate = true;
      };
    };
  };
}