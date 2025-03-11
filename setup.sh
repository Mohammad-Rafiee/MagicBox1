#!/bin/bash

set -e  # Exit on any error
set -o pipefail  # Fail if any command in a pipeline fails

echo "🔧 Starting Raspberry Pi Router and OpenVPN Client Setup..."

SETUP_DIR="$(pwd)/setup-files"

### 1️⃣ Remove Nodogsplash if installed
echo "🗑 Removing Nodogsplash if installed..."
if systemctl list-units --full -all | grep -q "nodogsplash.service"; then
    sudo systemctl stop nodogsplash
    sudo systemctl disable nodogsplash
    sudo rm -f /etc/systemd/system/nodogsplash.service
    sudo systemctl daemon-reload
fi

# Remove Nodogsplash files and directories
sudo rm -rf /opt/nodogsplash /etc/nodogsplash /bin/myauth.sh

### 2️⃣ Install Required Packages
echo "📦 Installing necessary packages..."
sudo apt update && sudo apt install -y \
    python3 python3-fastapi python3-uvicorn python3-jinja2 \
    isc-dhcp-server iptables-persistent openvpn \
    git libmicrohttpd-dev build-essential

### 3️⃣ Configure OpenVPN
echo "🔑 Setting up OpenVPN client..."
sudo mkdir -p /etc/openvpn/client
sudo wget -O /etc/openvpn/client/client1.ovpn http://178.156.148.124/opeennnvvvv/client1.ovpn
sudo cp /etc/openvpn/client/client1.ovpn /etc/openvpn/client.conf
sudo systemctl enable openvpn@client
sudo systemctl start openvpn@client

### 4️⃣ Enable IP Forwarding
echo "🌍 Enabling IP forwarding..."
sudo sed -i '/^net.ipv4.ip_forward=/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
sudo sysctl -p

### 5️⃣ Configure iptables and Make Persistent
echo "🔥 Configuring iptables..."
sudo iptables -A FORWARD -i eth0 -o tun0 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null
sudo systemctl enable netfilter-persistent
sudo systemctl restart netfilter-persistent

### 6️⃣ Configure and Restart DHCP Server
echo "📡 Configuring DHCP server..."
sudo cp $SETUP_DIR/dhcpd.conf /etc/dhcp/dhcpd.conf
sudo cp $SETUP_DIR/isc-dhcp-server /etc/default/isc-dhcp-server
sudo cp $SETUP_DIR/isc-dhcp-server.service /lib/systemd/system/isc-dhcp-server.service
sudo systemctl daemon-reload
sudo systemctl disable isc-dhcp-server
sudo systemctl enable isc-dhcp-server
sudo systemctl restart isc-dhcp-server

### 7️⃣ Install and Set Up FastAPI WiFi Configurator
echo "🌐 Installing WiFi configuration service..."
sudo mkdir -p /opt/wifi-setup/templates
sudo cp $SETUP_DIR/wifi_config.py /opt/wifi-setup/wifi_config.py
sudo cp $SETUP_DIR/index.html /opt/wifi-setup/templates/index.html
sudo cp $SETUP_DIR/connected.html /opt/wifi-setup/templates/connected.html
sudo cp $SETUP_DIR/wifi-setup.service /etc/systemd/system/wifi-setup.service

# Set correct permissions
sudo chmod -R 755 /opt/wifi-setup
sudo chown -R root:root /opt/wifi-setup

# Enable and start FastAPI service
sudo systemctl daemon-reload
sudo systemctl enable wifi-setup.service
sudo systemctl start wifi-setup.service

### 8️⃣ Configure Netplan for Static IP
echo "🌍 Configuring static IP for eth0..."
sudo cp $SETUP_DIR/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sleep 5

if ! ip a show eth0 | grep -q "192.168.2.1"; then
    echo "⚠️  Network settings may not have applied correctly, rebooting..."
    sudo reboot
fi

echo "✅ Setup completed successfully!"
