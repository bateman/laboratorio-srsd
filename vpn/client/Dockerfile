FROM ubuntu:22.04

# Install required packages
RUN apt-get update && \
    apt-get install -y \
    strongswan \
    libcharon-extra-plugins \
    net-tools \
    iproute2 \
    iputils-ping \
    curl \
    nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create directory for certificates and scripts
RUN mkdir -p /etc/ipsec.d/cacerts /scripts && \
    echo "Created directories" && \
    ls -la /

# Debug: List contents of build context
RUN echo "Contents of build context:" && ls -la /

# Copy scripts
COPY scripts/ /scripts/
RUN echo "After copying scripts:" && ls -la /scripts/

# Make scripts executable
RUN find /scripts -type f -name "*.sh" -exec chmod +x {} \; && \
    echo "Made scripts executable"

# Copy config files
COPY config/ipsec.conf /etc/ipsec.conf
COPY config/ipsec.secrets /etc/ipsec.secrets
COPY config/cacerts/ca-cert.pem /etc/ipsec.d/cacerts
RUN echo "After copying config files:" && \
    ls -la /etc/ | grep ipsec && \
    cat /etc/ipsec.conf && \
    cat /etc/ipsec.d/cacerts/ca-cert.pem

# Set working directory
WORKDIR /etc
RUN echo "Working directory set to:" && pwd

# Set entrypoint
ENTRYPOINT ["/scripts/start.sh"]
