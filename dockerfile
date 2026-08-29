FROM cgr.dev/chainguard/wolfi-base:latest

# =========================================================================
# STEP 1: FORCE THE HOSTNAME OVERRIDE
# This changes your prompt to "apex-core"
# =========================================================================
ENV HOSTNAME=apex-core

# Set up global environment variables for Bun and Node paths
ENV BUN_INSTALL=/root/.bun
ENV PATH=$BUN_INSTALL/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Step 2: Install OpenSSH, Python 3, Build Tools, Node.js, npm, and Bun dependencies (unzip/curl/bash)
RUN apk add --no-cache \
    openssh \
    python3 \
    py3-pip \
    build-base \
    cmake \
    ninja-build \
    git \
    shadow \
    bash \
    nodejs \
    npm \
    curl \
    unzip

# Step 3: Globally install Bun using official installer script
RUN curl -fsSL https://bun.sh/install | bash

# Step 4: Configure shell profiles (.bashrc and .profile) for persistent PATH access
RUN echo 'export BUN_INSTALL="$HOME/.bun"' >> /root/.bashrc && \
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /root/.bashrc && \
    echo 'export BUN_INSTALL="$HOME/.bun"' >> /root/.profile && \
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /root/.profile

# Step 5: Set root login credentials (usr: root / pass: root)
RUN echo "root:root" | chpasswd

# Step 6: Generate system host keys and create system folders
RUN ssh-keygen -A && mkdir -p /var/run/sshd /root/.ssh /var/www/html

# Step 7: Inject your public key and lock down directory permissions
RUN echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3TAnMJ6yUSPwcfVtSXjglaJ6DBgPdapBR56jphpLs8" > /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

# Step 8: Tune SSH server configuration rules
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "Port 8022" >> /etc/ssh/sshd_config

# Step 9: Create a basic landing page for Render's active uptime checks
RUN echo "<html><body><h1>Render Health Check Bypass Active (Wolfi OS + Bun + Node)</h1></body></html>" > /var/www/html/index.html

# Expose 10000 for Render to listen to, and 8022 for internal use
EXPOSE 8022 10000

# Step 10: Boot Python web server in background, spin up sshd, and hold the reverse tunnel open
CMD python3 -m http.server 10000 --directory /var/www/html > /dev/null 2>&1 & \
    /usr/sbin/sshd && \
    while true; do \
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=30 \
          -N \
          -R wolfie:22:localhost:8022 \
          choco@ssh-j.com; \
      sleep 5; \
    done
