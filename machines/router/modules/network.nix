{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # Network Interfaces, VLANs, and Bridges Configuration
  # ===========================================================================
  # This module configures the physical network topology:
  # - ens18: WAN interface (with VLAN 20 for PPPoE)
  # - ens19/ens20: LAN interfaces (bonded via bridges)
  # 
  # VLANs and Bridges:
  # - brlan (untagged): Main LAN network (10.71.71.0/24)
  # - brguest (VLAN 6): Guest network (10.71.72.0/24)
  # - briot (VLAN 10): IoT network (192.168.6.0/24)
  # - brdirect (VLAN 100): Direct WAN access + OpenVPN container (10.71.73.0/24)
  # ===========================================================================

  boot.kernel.sysctl = {
    # Enable IPv4 forwarding to allow routing between networks
    "net.ipv4.conf.all.forwarding" = true;
  };

  networking = {
    useDHCP = false;
    enableIPv6 = false;
    hostName = lib.mkForce "router";

    # VLAN configuration
    # VLAN 20 on ens18: PPPoE WAN connection
    # VLAN 6: Guest network (isolated network for visitors)
    # VLAN 10: IoT network (restricted network for smart devices)
    # VLAN 100: Direct WAN access (bypasses VPN for specific services)
    vlans = {
      "ens18.20" = { id = 20; interface = "ens18"; };
      "ens19.6" = { id = 6; interface = "ens19"; };
      "ens19.10" = { id = 10; interface = "ens19"; };
      "ens19.100" = { id = 100; interface = "ens19"; };
      "ens20.6" = { id = 6; interface = "ens20"; };
      "ens20.10" = { id = 10; interface = "ens20"; };
      "ens20.100" = { id = 100; interface = "ens20"; };
    };

    # Bridge configuration
    # Each bridge bonds ens19 and ens20 for redundancy/load balancing
    # This allows devices to connect via either physical port seamlessly
    bridges = {
      brlan = { 
        interfaces = [ "ens19" "ens20" ];
      };
      brguest = { 
        interfaces = [ "ens19.6" "ens20.6" ];
      };
      briot = { 
        interfaces = [ "ens19.10" "ens20.10" ];
      };
      brdirect = { 
        interfaces = [ "ens19.100" "ens20.100" ];
      };
    };

    # Interface IP addressing
    # All physical interfaces use static configuration (no DHCP)
    # Only bridge interfaces have IP addresses assigned
    interfaces = {
      # Physical interfaces - no IP addresses
      ens18.useDHCP = false;
      "ens18.20".useDHCP = false;
      ens19.useDHCP = false;
      ens20.useDHCP = false;

      # Bridge interfaces - static IPs, act as gateways for their respective networks
      brlan = { 
        useDHCP = false; 
        ipv4.addresses = [{ 
          address = "10.71.71.1"; 
          prefixLength = 24; 
        }]; 
      };
      brguest = { 
        useDHCP = false; 
        ipv4.addresses = [{ 
          address = "10.71.72.1"; 
          prefixLength = 24; 
        }]; 
      };
      briot = { 
        useDHCP = false; 
        ipv4.addresses = [{ 
          address = "192.168.6.1"; 
          prefixLength = 24; 
        }]; 
      };
      brdirect = { 
        useDHCP = false; 
        ipv4.addresses = [{ 
          address = "10.71.73.1"; 
          prefixLength = 24; 
        }]; 
      };
    };

    # Disable built-in NAT and firewall - we use nftables instead
    nat.enable = false;
    firewall.enable = false;
  };


}
