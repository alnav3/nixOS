# ===========================================================================
# Router Network Library - Single Source of Truth
# ===========================================================================
# This file defines all network parameters in one place.
# All router modules should import and use these definitions.
#
# Usage: let netlib = import ./lib.nix; in { ... }
# ===========================================================================

rec {
  # ---------------------------------------------------------------------------
  # Physical Interfaces
  # ---------------------------------------------------------------------------
  interfaces = {
    wan = "ens18";
    lan1 = "ens19";
    lan2 = "ens20";
  };

  # ---------------------------------------------------------------------------
  # VLAN Definitions
  # ---------------------------------------------------------------------------
  # Each VLAN has:
  #   - id: VLAN tag number
  #   - bridge: bridge interface name
  #   - subnet: network address with CIDR
  #   - gateway: router IP on this VLAN
  #   - dhcpRange: { start, end } for DHCP pool
  #   - dhcpTag: dnsmasq tag name
  #   - description: human-readable description
  # ---------------------------------------------------------------------------
  vlans = {
    # PPPoE WAN VLAN (special - no bridge/DHCP)
    wan = {
      id = 20;
      interface = interfaces.wan;
      description = "PPPoE WAN connection";
    };

    # Main LAN - untagged on LAN ports
    lan = {
      id = null;  # Untagged
      bridge = "brlan";
      subnet = "10.71.71.0/24";
      gateway = "10.71.71.1";
      dhcpRange = { start = "10.71.71.100"; end = "10.71.71.200"; };
      dhcpTag = "lan";
      description = "Main trusted network";
    };

    # Guest Network
    guest = {
      id = 6;
      bridge = "brguest";
      subnet = "10.71.72.0/24";
      gateway = "10.71.72.1";
      dhcpRange = { start = "10.71.72.100"; end = "10.71.72.200"; };
      dhcpTag = "guest";
      description = "Isolated guest network";
    };

    # IoT Network
    iot = {
      id = 10;
      bridge = "briot";
      subnet = "192.168.6.0/24";
      gateway = "192.168.6.1";
      dhcpRange = { start = "192.168.6.100"; end = "192.168.6.200"; };
      dhcpTag = "iot";
      description = "Restricted IoT devices";
    };

    # Homelab Network
    homelab = {
      id = 50;
      bridge = "brhomelab";
      subnet = "10.71.74.0/24";
      gateway = "10.71.74.1";
      dhcpRange = { start = "10.71.74.100"; end = "10.71.74.200"; };
      dhcpTag = "homelab";
      description = "Isolated homelab devices";
      # Server devices that are accessible from all networks
      servers = [ "10.71.74.10" "10.71.74.75" "10.71.74.193" ];
    };

    # Direct WAN Access Network
    direct = {
      id = 100;
      bridge = "brdirect";
      subnet = "10.71.73.0/24";
      gateway = "10.71.73.1";
      dhcpRange = { start = "10.71.73.100"; end = "10.71.73.200"; };
      dhcpTag = "direct";
      description = "Direct WAN access + OpenVPN";
    };
  };

  # ---------------------------------------------------------------------------
  # OpenVPN Configuration
  # ---------------------------------------------------------------------------
  openvpn = {
    containerIp = "10.71.73.10";
    clientSubnet = "10.8.0.0/24";
    port = 1194;
  };

  # ---------------------------------------------------------------------------
  # Special Network Addresses
  # ---------------------------------------------------------------------------
  special = {
    # Wildcard DNS target (reverse proxy)
    wildcardDns = "10.71.71.75";
    # Port forwarding target
    portForwardTarget = "10.71.71.193";
  };

  # ---------------------------------------------------------------------------
  # Helper Functions
  # ---------------------------------------------------------------------------

  # Get all VLANs that have bridges (excludes WAN)
  bridgedVlans = builtins.filter (v: vlans.${v} ? bridge) (builtins.attrNames vlans);

  # Get all bridge names
  allBridges = map (v: vlans.${v}.bridge) bridgedVlans;

  # Get VLAN interface name for a given VLAN and physical interface
  # e.g., vlanInterface "guest" "ens19" -> "ens19.6"
  vlanInterface = vlanName: physIface:
    if vlans.${vlanName}.id == null
    then physIface  # Untagged
    else "${physIface}.${toString vlans.${vlanName}.id}";

  # Generate VLAN definitions for networking.vlans
  # Returns attrset like: { "ens19.6" = { id = 6; interface = "ens19"; }; ... }
  mkVlanDefs = let
    mkVlanForIface = vlanName: iface:
      if vlans.${vlanName}.id == null
      then {}  # Skip untagged VLANs
      else {
        "${iface}.${toString vlans.${vlanName}.id}" = {
          id = vlans.${vlanName}.id;
          interface = iface;
        };
      };
    # Generate for both LAN interfaces
    mkVlanBoth = vlanName:
      (mkVlanForIface vlanName interfaces.lan1) //
      (mkVlanForIface vlanName interfaces.lan2);
  in
    # WAN VLAN is special (only on WAN interface)
    { "${interfaces.wan}.${toString vlans.wan.id}" = { 
        id = vlans.wan.id; 
        interface = interfaces.wan; 
      }; 
    } //
    # All other VLANs on both LAN interfaces
    builtins.foldl' (acc: v: acc // (mkVlanBoth v)) {} 
      (builtins.filter (v: v != "wan") (builtins.attrNames vlans));

  # Generate bridge definitions for networking.bridges
  mkBridgeDefs = let
    mkBridge = vlanName:
      if vlans.${vlanName} ? bridge
      then {
        ${vlans.${vlanName}.bridge} = {
          interfaces = 
            if vlans.${vlanName}.id == null
            then [ interfaces.lan1 interfaces.lan2 ]  # Untagged
            else [ 
              (vlanInterface vlanName interfaces.lan1)
              (vlanInterface vlanName interfaces.lan2)
            ];
        };
      }
      else {};
  in
    builtins.foldl' (acc: v: acc // (mkBridge v)) {} (builtins.attrNames vlans);

  # Generate interface IP configurations
  mkInterfaceIps = let
    mkIfaceIp = vlanName:
      if vlans.${vlanName} ? bridge && vlans.${vlanName} ? gateway
      then {
        ${vlans.${vlanName}.bridge} = {
          useDHCP = false;
          ipv4.addresses = [{
            address = vlans.${vlanName}.gateway;
            prefixLength = 24;
          }];
        };
      }
      else {};
  in
    # Physical interfaces - no DHCP
    {
      ${interfaces.wan}.useDHCP = false;
      "${interfaces.wan}.${toString vlans.wan.id}".useDHCP = false;
      ${interfaces.lan1}.useDHCP = false;
      ${interfaces.lan2}.useDHCP = false;
    } //
    # Bridge interfaces with IPs
    builtins.foldl' (acc: v: acc // (mkIfaceIp v)) {} (builtins.attrNames vlans);

  # Generate DHCP ranges for dnsmasq
  # Returns list like: [ "set:lan,10.71.71.100,10.71.71.200,24h" ... ]
  mkDhcpRanges = let
    mkRange = vlanName:
      if vlans.${vlanName} ? dhcpRange
      then [ "set:${vlans.${vlanName}.dhcpTag},${vlans.${vlanName}.dhcpRange.start},${vlans.${vlanName}.dhcpRange.end},24h" ]
      else [];
  in
    builtins.concatLists (map mkRange (builtins.attrNames vlans));

  # Generate DHCP options for dnsmasq
  # Returns list of options per network
  mkDhcpOptions = let
    mkOpts = vlanName:
      if vlans.${vlanName} ? dhcpTag && vlans.${vlanName} ? gateway
      then [
        "tag:${vlans.${vlanName}.dhcpTag},option:router,${vlans.${vlanName}.gateway}"
        "tag:${vlans.${vlanName}.dhcpTag},option:dns-server,${vlans.${vlanName}.gateway}"
        "tag:${vlans.${vlanName}.dhcpTag},option:ntp-server,${vlans.${vlanName}.gateway}"
        "tag:${vlans.${vlanName}.dhcpTag},option:domain-name,home"
      ]
      else [];
  in
    builtins.concatLists (map mkOpts (builtins.attrNames vlans));

  # Get all subnets for NTP allow rules
  # Returns list like: [ "10.71.71.0/24" "10.71.72.0/24" ... ]
  allSubnets = let
    getSubnet = vlanName:
      if vlans.${vlanName} ? subnet
      then [ vlans.${vlanName}.subnet ]
      else [];
  in
    builtins.concatLists (map getSubnet (builtins.attrNames vlans))
    ++ [ openvpn.clientSubnet ];

  # Get homelab server IPs as a formatted nftables set
  homelabServersNft = builtins.concatStringsSep ", " vlans.homelab.servers;
}
