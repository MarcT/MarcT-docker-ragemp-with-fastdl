# ---- Stage: Debian base with Nginx and RageMP ----
FROM debian:bookworm-slim

# Expose ports
EXPOSE 80
EXPOSE 20005
EXPOSE 22005/udp
EXPOSE 22006

# Install Nginx with extras and runtime dependencies
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
    && rm -rf /var/lib/apt/lists/*

# Set up RageMP
WORKDIR /ragemp

RUN wget https://cdn.rage.mp/updater/prerelease/server-files/linux_x64.tar.gz && \
    tar -xvf linux_x64.tar.gz && \
    rm linux_x64.tar.gz

WORKDIR /ragemp/ragemp-srv

# Add scripts
COPY start_server.sh /ragemp/ragemp-srv/
COPY config-generator.pl /ragemp/

# Start Nginx in the background and run RageMP server
CMD service nginx start && ./start_server.sh