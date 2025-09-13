# ---- Base image ----
FROM debian:bookworm-slim

# Expose necessary ports
EXPOSE 80
EXPOSE 20005
EXPOSE 22005/udp
EXPOSE 22006

# Install Nginx extras and dependencies
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

# Set working directory for RageMP
WORKDIR /ragemp

# Download and extract RageMP server files
RUN wget https://cdn.rage.mp/updater/prerelease/server-files/linux_x64.tar.gz && \
    tar -xvf linux_x64.tar.gz && \
    rm linux_x64.tar.gz

# Copy scripts
COPY start.sh ./ragemp-srv/
COPY config-generator.pl ./

# Make start.sh executable
RUN chmod +x /ragemp/ragemp-srv/start.sh

# Start both Nginx and RageMP with colored logging & restart
CMD ["bash", "/ragemp/ragemp-srv/start.sh"]
