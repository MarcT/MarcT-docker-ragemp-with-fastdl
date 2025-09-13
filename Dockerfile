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

# Remove unsupported module configs (those not included in Debian)
RUN rm -f /etc/nginx/modules-enabled/10-mod-http-ndk.conf \
          /etc/nginx/modules-enabled/50-mod-http-auth-pam.conf \
          /etc/nginx/modules-enabled/50-mod-http-dav-ext.conf \
          /etc/nginx/modules-enabled/50-mod-http-geoip2.conf \
          /etc/nginx/modules-enabled/50-mod-http-lua.conf \
          /etc/nginx/modules-enabled/50-mod-http-perl.conf \
          /etc/nginx/modules-enabled/50-mod-http-upstream-fair.conf \
          /etc/nginx/modules-enabled/50-mod-nchan.conf \
          /etc/nginx/modules-enabled/70-mod-stream-geoip2.conf

# Fix paths for remaining supported modules
RUN sed -i 's|modules/ngx_http_geoip_module.so|/usr/lib/nginx/modules/ngx_http_geoip_module.so|' /etc/nginx/modules-enabled/*.conf \
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
