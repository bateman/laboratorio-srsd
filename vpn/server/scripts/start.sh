#!/bin/bash
set -e

# Function to generate certificates if they don't exist
setup_certificates() {
    # Check if certificates already exist
    if [ -f "/etc/ipsec.d/certs/server-cert.pem" ]; then
        echo "Certificates already exist. Skipping certificate generation."
        return
    fi
    
    echo "Generating certificates..."
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # Update ipsec.conf with actual server IP
    sed -i '' "s/@SERVER_IP@/$SERVER_IP/g" /etc/ipsec.conf
    
    # Generate CA key
    pki --gen --type rsa --size 4096 --outform pem > /root/pki/private/ca-key.pem
    
    # Create CA certificate
    pki --self --ca --lifetime 3650 --in /root/pki/private/ca-key.pem \
        --type rsa --dn "CN=VPN root CA" --outform pem > /root/pki/cacerts/ca-cert.pem
    
    # Generate server key
    pki --gen --type rsa --size 4096 --outform pem > /root/pki/private/server-key.pem
    
    # Generate server certificate and sign it with CA
    pki --pub --in /root/pki/private/server-key.pem --type rsa \
    | pki --issue --lifetime 1825 \
        --cacert /root/pki/cacerts/ca-cert.pem \
        --cakey /root/pki/private/ca-key.pem \
        --dn "CN=$SERVER_IP" --san @$SERVER_IP --san $SERVER_IP \
        --flag serverAuth --flag ikeIntermediate --outform pem \
        > /root/pki/certs/server-cert.pem
    
    # Copy certificates to StrongSwan directory
    cp -r /root/pki/* /etc/ipsec.d/
    
    # Print CA certificate for client configuration
    echo "CA Certificate (copy this to client's /etc/ipsec.d/cacerts/ca-cert.pem):"
    cat /etc/ipsec.d/cacerts/ca-cert.pem
}

# Function to configure firewall and IPtables
setup_firewall() {
    # Get the default interface
    DEFAULT_INTERFACE=$(ip route show default | grep -Po '(?<=dev )\w+')
    
    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Set up NAT for VPN clients
    iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o $DEFAULT_INTERFACE -m policy --pol ipsec --dir out -j ACCEPT
    iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o $DEFAULT_INTERFACE -j MASQUERADE
    
    # Set up mangle rules for TCP MSS clamping
    iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.0/24 -o $DEFAULT_INTERFACE -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
    
    # Allow IPsec traffic
    iptables -A INPUT -p udp --dport 500 -j ACCEPT
    iptables -A INPUT -p udp --dport 4500 -j ACCEPT
    iptables -A FORWARD --match policy --pol ipsec --dir in --proto esp -s 10.10.10.0/24 -j ACCEPT
    iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d 10.10.10.0/24 -j ACCEPT
}

# Main execution
echo "Starting StrongSwan VPN Server..."
setup_certificates
setup_firewall

# Start StrongSwan in foreground
exec ipsec start --nofork
