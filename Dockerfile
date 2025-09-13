# ---- Stage 1: Build and prepare nginx with modules on Alpine ----
FROM nginx:1.28.0-alpine-slim AS nginx-build

ENV NJS_VERSION 0.8.10
ENV NJS_RELEASE 1

RUN set -x \
    && apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-r${DYNPKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-r${DYNPKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-r${DYNPKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}.${NJS_VERSION}-r${NJS_RELEASE} \
    " \
    && apk add --no-cache --virtual .checksum-deps openssl \
    && case "$apkArch" in \
        x86_64|aarch64) \
            apk add -X "https://nginx.org/packages/alpine/v$(egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release)/main" --no-cache $nginxPackages \
            ;; \
        *) \
            tempDir="$(mktemp -d)" \
            && chown nobody:nobody $tempDir \
            && apk add --no-cache --virtual .build-deps \
                gcc libc-dev make openssl-dev pcre2-dev zlib-dev linux-headers \
                libxslt-dev gd-dev geoip-dev libedit-dev bash alpine-sdk findutils curl \
            && su nobody -s /bin/sh -c " \
                export HOME=${tempDir} \
                && cd ${tempDir} \
                && curl -f -L -O https://github.com/nginx/pkg-oss/archive/${NGINX_VERSION}-${PKG_RELEASE}.tar.gz \
                && PKGOSSCHECKSUM=\"517bc18954ccf4efddd51986584ca1f37966833ad342a297e1fe58fd0faf14c5a4dabcb23519dca433878a2927a95d6bea05a6749ee2fa67a33bf24cdc41b1e4 *${NGINX_VERSION}-${PKG_RELEASE}.tar.gz\" \
                && if [ \"\$(openssl sha512 -r ${NGINX_VERSION}-${PKG_RELEASE}.tar.gz)\" = \"\$PKGOSSCHECKSUM\" ]; then \
                    echo \"pkg-oss tarball checksum verification succeeded!\"; \
                else \
                    echo \"pkg-oss tarball checksum verification failed!\"; \
                    exit 1; \
                fi \
                && tar xzvf ${NGINX_VERSION}-${PKG_RELEASE}.tar.gz \
                && cd pkg-oss-${NGINX_VERSION}-${PKG_RELEASE}/alpine \
                && make module-geoip module-image-filter module-njs module-xslt \
                && apk index --allow-untrusted -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
                && abuild-sign -k ${tempDir}/.abuild/abuild-key.rsa ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz" \
            && cp ${tempDir}/.abuild/abuild-key.rsa.pub /etc/apk/keys/ \
            && apk del --no-network .build-deps \
            && apk add -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
            ;; \
    esac \
    && apk del --no-network .checksum-deps \
    && rm -rf /etc/apk/keys/abuild-key.rsa.pub || true \
    && apk add --no-cache curl ca-certificates

# ---- Stage 2: RageMP server on Debian ----
FROM debian:bookworm-slim

# Copy nginx binary and configuration from the build stage
COPY --from=nginx-build /etc/nginx /etc/nginx
COPY --from=nginx-build /usr/sbin/nginx /usr/sbin/nginx
COPY --from=nginx-build /usr/lib/nginx /usr/lib/nginx

# Expose only port 80 for Nginx, plus RageMP ports
EXPOSE 80
EXPOSE 20005
EXPOSE 22005/udp
EXPOSE 22006

RUN apt update && apt install -y \
    wget liblocal-lib-perl libjson-perl libatomic1 procps curl ca-certificates \
    && apt clean autoclean \
    && apt autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/

WORKDIR /ragemp

RUN wget https://cdn.rage.mp/updater/prerelease/server-files/linux_x64.tar.gz && \
    tar -xvf ./linux_x64.tar.gz && \
    rm -rf ./linux_x64.tar.gz

WORKDIR /ragemp/ragemp-srv

ADD start_server.sh /ragemp/ragemp-srv
ADD config-generator.pl /ragemp/

# Start Nginx in the background and run the RageMP server
CMD service nginx start && ./start_server.sh
