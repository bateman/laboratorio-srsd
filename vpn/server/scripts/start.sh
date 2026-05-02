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
    sed -i "s/@SERVER_IP@/$SERVER_IP/g" /etc/ipsec.conf
    
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
        --flag serverAuth --flag ipsecIKE --outform pem \
        > /root/pki/certs/server-cert.pem
    
    # Copy certificates to StrongSwan directory
    cp -r /root/pki/* /etc/ipsec.d/
    
    # Print CA certificate for client configuration
    echo "CA Certificate (copy this to client's /etc/ipsec.d/cacerts/ca-cert.pem):"
    cat /etc/ipsec.d/cacerts/ca-cert.pem
}

# Function to configure firewall and IPtables
setup_firewall() {
    DEFAULT_INTERFACE=$(ip route show default | grep -Po '(?<=dev )\w+')

    # 1. Pulisci stato precedente (idempotenza, utile se la funzione viene rieseguita)
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F

    # 2. Durante il setup teniamo policy ACCEPT, così non ci auto-blocchiamo
    #    mentre stiamo aggiungendo le ACCEPT rules. La chiusura è in fondo.
    iptables -P INPUT   ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT  ACCEPT

    # 3. IP forwarding + NAT (invariato rispetto allo script originale)
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o $DEFAULT_INTERFACE \
        -m policy --pol ipsec --dir out -j ACCEPT
    iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o $DEFAULT_INTERFACE \
        -j MASQUERADE

    # 4. MSS clamping 
    iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in \
        -s 10.10.10.0/24 -o $DEFAULT_INTERFACE -p tcp -m tcp \
        --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 \
        -j TCPMSS --set-mss 1360

    # 5. INPUT: ACCEPT esplicite (devono precedere il DROP)
    # 5a. loopback sempre
    iptables -A INPUT -i lo -j ACCEPT
    # 5b. ritorno di connessioni già aperte dal server (DNS, apt-get, ecc.)
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    # 5c. ICMP echo-request rate-limitato (utile per ping di debug; togliere se non vuoi)
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 4/sec -j ACCEPT
    # 5d. IKE e NAT-Traversal
    iptables -A INPUT -p udp --dport 500  -j ACCEPT
    iptables -A INPUT -p udp --dport 4500 -j ACCEPT
    # 5e. ESP "nativo" (protocollo 50), per il caso senza NAT-T
    iptables -A INPUT -p esp -j ACCEPT
    # 5f. SSH per amministrare il container (rimuovi se accedi solo via `docker exec`)
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT

    # 6. FORWARD: ACCEPT esplicite
    # 6a. ritorno di sessioni già aperte da client VPN verso Internet
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    # 6b. traffico VPN dopo decifratura ESP, in entrambe le direzioni (dallo script originale)
    iptables -A FORWARD --match policy --pol ipsec --dir in  --proto esp -s 10.10.10.0/24 -j ACCEPT
    iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d 10.10.10.0/24 -j ACCEPT

    # 7. Logging dei pacchetti che STANNO PER essere droppati (limit per evitare flooding)
    iptables -A INPUT   -m limit --limit 5/min -j LOG --log-prefix "fw-DROP-IN: "   --log-level 7
    iptables -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "fw-DROP-FWD: "  --log-level 7

    # 8. CHIUDI: ora che le eccezioni sono in place, default policy DROP
    iptables -P INPUT   DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT  ACCEPT     # il server VPN deve poter iniziare sessioni (DNS, NTP, log, ...)
}

# Main execution
echo "Starting StrongSwan VPN Server..."
setup_certificates
setup_firewall

# Start StrongSwan in foreground
exec ipsec start --nofork
