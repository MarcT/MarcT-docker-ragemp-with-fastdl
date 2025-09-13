# ---- Base image ----
FROM debian:bookworm-slim

# Expose ports for Nginx and RageMP
EXPOSE 80
EXPOSE 20005
EXPOSE 22005/udp
EXPOSE 22006

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx-extras \
    wget \
    curl \
    ca-certificates \
    libatomic1 \
    procps \
    libjson-perl \
    liblocal-lib-perl \
    perl \
    tar \
    && rm -rf /var/lib/apt/lists/*

# Patch Nginx module .conf files to correct Debian paths
RUN for f in /etc/nginx/modules-enabled/*.conf; do \
        sed -i 's|modules/|/usr/lib/nginx/modules/|g' "$f"; \
    done

# Set working directory
WORKDIR /ragemp

# Download and extract RageMP server
RUN wget https://cdn.rage.mp/updater/prerelease/server-files/linux_x64.tar.gz && \
    tar -xvf linux_x64.tar.gz && \
    rm linux_x64.tar.gz

# Copy scripts into the extracted server folder
COPY start.sh ./ragemp-srv/
COPY config-generator.pl ./

# Make scripts executable
RUN chmod +x /ragemp/config-generator.pl /ragemp/ragemp-srv/start.sh

# Set working directory to ragemp-srv when starting container
WORKDIR /ragemp/ragemp-srv

# Start both Nginx and RageMP with log colorization & restart
CMD ["bash", "./start.sh"]
