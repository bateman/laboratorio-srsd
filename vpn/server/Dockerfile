FROM ubuntu:22.04

# Install required packages
RUN apt-get update && \
    apt-get install -y \
    strongswan \
    strongswan-pki \
    libcharon-extra-plugins \
    libcharon-extauth-plugins \
    libstrongswan-extra-plugins \
    libtss2-tcti-tabrmd0 \
    ufw \
    iptables \
    net-tools \
    iproute2 \
    iputils-ping \
    nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create directory structure for PKI
RUN mkdir -p /root/pki/cacerts \
    /root/pki/certs \
    /root/pki/private \
    && chmod 700 /root/pki

# Copy setup scripts
COPY ./scripts /scripts
RUN chmod +x /scripts/*.sh

# Configure StrongSwan
COPY ./config/ipsec.conf /etc/ipsec.conf
COPY ./config/ipsec.secrets /etc/ipsec.secrets

# Expose ports
EXPOSE 500/udp 4500/udp

# Set working directory
WORKDIR /etc

# Set entrypoint
ENTRYPOINT ["/scripts/start.sh"]
