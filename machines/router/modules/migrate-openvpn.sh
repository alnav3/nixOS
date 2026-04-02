#!/bin/bash
# Migration script to move existing OpenVPN state to container directories
set -euo pipefail

echo "Migrating OpenVPN state to container directories..."

# Create container directories
sudo mkdir -p /var/lib/openvpn-container
sudo mkdir -p /var/log/openvpn-container

# Copy existing state if it exists
if [ -d "/var/lib/openvpn" ]; then
    echo "Copying /var/lib/openvpn to /var/lib/openvpn-container..."
    sudo cp -r /var/lib/openvpn/* /var/lib/openvpn-container/ || true
fi

if [ -d "/var/log/openvpn" ]; then
    echo "Copying /var/log/openvpn to /var/log/openvpn-container..."
    sudo cp -r /var/log/openvpn/* /var/log/openvpn-container/ || true
fi

# Set proper permissions
sudo chown -R root:root /var/lib/openvpn-container
sudo chown -R root:root /var/log/openvpn-container
sudo chmod 700 /var/lib/openvpn-container

echo "Migration completed!"
echo ""
echo "After rebuilding with the new configuration:"
echo "1. The OpenVPN server will run in a container at 10.71.73.10"
echo "2. Port 1194 will be forwarded from the host to the container"
echo "3. The container uses VLAN 100 (brdirect) which bypasses WireGuard"
echo "4. OpenVPN clients will route through the container to reach networks"
echo ""
echo "To test:"
echo "1. sudo nixos-rebuild switch"
echo "2. Check container status: sudo systemctl status container@openvpn"
echo "3. Check OpenVPN status: sudo nixos-container run openvpn systemctl status openvpn-home"