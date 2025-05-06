#!/bin/bash
set -e

echo "Stopping and existing container..."
docker compose down

# Comment out to ensure a fresh start
#echo "Removing existing images..."
#docker rmi $(docker images -q vpn-client_vpn-client) 2>/dev/null || true

#echo "Cleaning up build cache..."
#docker builder prune -f

echo "Verifying directory structure..."
if [ ! -d "config/cacerts" ]; then
  echo "Creating config directory..."
  mkdir -p config/cacerts
fi

if [ ! -d "scripts" ]; then
  echo "Creating scripts directory..."
  mkdir -p scripts
fi

# Check if ipsec.conf exists
if [ ! -f "config/ipsec.conf" ]; then
  echo "Creating sample ipsec.conf..."
  cat > config/ipsec.conf << EOF
config setup
    charondebug="ike 1, knl 1, cfg 0"

conn ikev2-vpn
    right=@SERVER_IP@
    rightid=@SERVER_IP@
    rightsubnet=0.0.0.0/0
    rightauth=pubkey
    leftsourceip=%config
    leftid=vpnuser
    leftauth=eap-mschapv2
    eap_identity=%identity
    auto=start
EOF
fi

# Check if ipsec.secrets exists
if [ ! -f "config/ipsec.secrets" ]; then
  echo "Creating sample ipsec.secrets..."
  cat > config/ipsec.secrets << EOF
vpnuser : EAP "vpnpassword"
EOF
fi

# Check if start.sh exists
if [ ! -f "scripts/start.sh" ]; then
  echo "Creating sample start.sh..."
  cat > scripts/start.sh << EOF
#!/bin/bash
set -e

# Function to setup client connection
setup_client() {
    if [ -z "\$SERVER_IP" ]; then
        SERVER_IP="172.20.0.2"
        echo "Could not resolve vpn-server, using default IP: \$SERVER_IP"
    else
        echo "Resolved vpn-server to IP: \$SERVER_IP"
    fi
    
    # Update ipsec.conf with actual server IP
    sed -i "s/@SERVER_IP@/\$SERVER_IP/g" /etc/ipsec.conf
    
    # Check if CA certificate exists
    if [ ! -f "/etc/ipsec.d/cacerts/ca-cert.pem" ]; then
        echo "CA certificate not found. Creating an empty placeholder."
        touch /etc/ipsec.d/cacerts/ca-cert.pem
    fi
}

# Function to display client status
show_status() {
    echo "VPN client IP addresses:"
    ip addr
    
    echo "VPN connection status:"
    ipsec status || echo "IPsec not running"
}

# Main execution
echo "Starting StrongSwan VPN Client..."
setup_client

# Start StrongSwan
ipsec start

# Show initial status
sleep 5
show_status

# Keep container running
tail -f /dev/null
EOF
  chmod +x scripts/start.sh
fi

# Get the SERVER address
SERVER_IP=$(docker exec vpn-server hostname -I | awk '{print $1}')
echo "SERVER_IP=$SERVER_IP" > .env

echo "Copying CA certificates to vpn-client config directory"
docker exec vpn-server cat /etc/ipsec.d/cacerts/ca-cert.pem > config/cacerts/ca-cert.pem 2>/dev/null || echo "CA cert not yet available, will retry"

#if [ -f "config/cacerts/ca-cert.pem" ]; then
#    docker cp config/cacerts/ca-cert.pem vpn-client:/etc/ipsec.d/cacerts/
#fi

echo "Building and starting containers..."
docker compose build
docker compose up -d

echo "Restarting the container"
docker restart vpn-client

# Commented out - for debug purposes only
#echo "Container logs:"
#docker logs vpn-client

#echo "Verifying container state:"
#docker exec vpn-client ls -la /scripts/
#docker exec vpn-client ls -la /etc/ | grep ipsec
#docker exec vpn-client ls -la /etc/ipsec.d/cacerts | grep ca-cert.pem
