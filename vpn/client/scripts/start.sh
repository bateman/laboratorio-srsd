#!/bin/bash
set -e

# Function to setup client connection
setup_client() {
    # Update ipsec.conf with actual server IP
    sed -i "s/@SERVER_IP@/$SERVER_IP/g" /etc/ipsec.conf

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
    ipsec status
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
