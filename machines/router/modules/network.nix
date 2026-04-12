{ config, lib, pkgs, ... }:

let
  netlib = import ./lib.nix;
in
{
  # ===========================================================================
  # Network Interfaces, VLANs, and Bridges Configuration
  # ===========================================================================
  # This module configures the physical network topology using definitions
  # from lib.nix as the single source of truth.
  #
  # Physical Interfaces:
  # - ${netlib.interfaces.wan}: WAN interface (with VLAN ${toString netlib.vlans.wan.id} for PPPoE)
  # - ${netlib.interfaces.lan1}/${netlib.interfaces.lan2}: LAN interfaces (bonded via bridges)
  # 
  # VLANs and Bridges (defined in lib.nix):
  # - brlan (untagged): Main LAN network (${netlib.vlans.lan.subnet})
  # - brguest (VLAN ${toString netlib.vlans.guest.id}): Guest network (${netlib.vlans.guest.subnet})
  # - briot (VLAN ${toString netlib.vlans.iot.id}): IoT network (${netlib.vlans.iot.subnet})
  # - brhomelab (VLAN ${toString netlib.vlans.homelab.id}): Homelab network (${netlib.vlans.homelab.subnet})
  # - brdirect (VLAN ${toString netlib.vlans.direct.id}): Direct WAN access (${netlib.vlans.direct.subnet})
  # ===========================================================================

  boot.kernel.sysctl = {
    # Enable IPv4 forwarding to allow routing between networks
    "net.ipv4.conf.all.forwarding" = true;
  };

  networking = {
    useDHCP = false;
    enableIPv6 = false;
    hostName = lib.mkForce "router";

    # VLAN configuration - generated from lib.nix
    vlans = netlib.mkVlanDefs;

    # Bridge configuration - generated from lib.nix
    bridges = netlib.mkBridgeDefs;

    # Interface IP addressing - generated from lib.nix
    interfaces = netlib.mkInterfaceIps;

    # Disable built-in NAT and firewall - we use nftables instead
    nat.enable = false;
    firewall.enable = false;
  };
}
