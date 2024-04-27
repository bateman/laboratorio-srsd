# syntax=docker/dockerfile:1.4
FROM alpine:latest

# Install packages required for SSH and Python
RUN apk add --no-cache openssh-server python3 curl

# Disable password authentication for SSH and enable root login
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i '/AllowTcpForwarding/d' /etc/ssh/sshd_config && \
    sed -i '/PermitOpen/d' /etc/ssh/sshd_config 

# Create an SSH directory and copy locally available public keys
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh 

# Generate host keys for SSH
RUN ssh-keygen -A


# Expose ports for SSH not Python HTTP server
EXPOSE 22 

# Start Python HTTP server in the background
# Prepare the entrypoint that starts the daemons:
COPY --chmod=755 <<'EOF' /entrypoint.sh
#!/bin/sh
set -euo pipefail

for file in /tmp/ssh/*.pub; do
  cat ${file} >> /root/.ssh/authorized_keys
done
chmod 600 /root/.ssh/authorized_keys

/usr/sbin/sshd -e -D &
python3 -m http.server --bind 127.0.0.1 80 &

sleep infinity
EOF

# Run it:
CMD ["/entrypoint.sh"]
