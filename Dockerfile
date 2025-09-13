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

# Fix Nginx module paths for Debian
RUN sed -i 's|modules/ndk_http_module.so|/usr/lib/nginx/modules/ndk_http_module.so|' /etc/nginx/modules-enabled/*.conf \
 && sed -i 's|modules/ngx_http_geoip_module.so|/usr/lib/nginx/modules/ngx_http_geoip_module.so|' /etc/nginx/modules-enabled/*.conf \
 && sed -i 's|modules/ngx_http_xslt_filter_module.so|/usr/lib/nginx/modules/ngx_http_xslt_filter_module.so|' /etc/nginx/modules-enabled/*.conf \
 && sed -i 's|modules/ngx_http_image_filter_module.so|/usr/lib/nginx/modules/ngx_http_image_filter_module.so|' /etc/nginx/modules-enabled/*.conf \
 && sed -i 's|modules/ngx_http_js_module.so|/usr/lib/nginx/modules/ngx_http_js_module.so|' /etc/nginx/modules-enabled/*.conf

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
