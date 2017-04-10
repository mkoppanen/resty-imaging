FROM openresty/openresty:alpine

WORKDIR /tmp
EXPOSE 8080

COPY ./entrypoint.sh /entrypoint.sh
COPY ./helper-lib    /tmp/helper-lib

RUN apk add --no-cache --virtual build-deps \
        gcc g++ make libc-dev automake libtool tar gettext git autoconf gtk-doc build-base curl \
        glib-dev libpng-dev libwebp-dev libexif-dev libxml2-dev libjpeg-turbo-dev gobject-introspection-dev tiff-dev giflib-dev librsvg-dev \
    && \
    apk add --no-cache \
        glib libpng libwebp libexif libxml2 libjpeg-turbo gobject-introspection tiff giflib librsvg ca-certificates libstdc++ libc6-compat \
    && \
    git clone https://github.com/jcupitt/libvips.git \
    && \
    cd libvips \
    && \
    CFLAGS="-O3 -g" ./autogen.sh --disable-python --without-gsf \
    && \
    make -j8 \
    && \
    make install \
    && \
    ldconfig /usr/local/lib \
    && \
    mkdir -p /var/run/openresty-imaging/logs \
    && \
    chmod +x /entrypoint.sh \
    && \
    /usr/local/openresty/bin/opm install pintsized/lua-resty-http \
    && \
    /usr/local/openresty/bin/opm install bungle/lua-resty-prettycjson \
    && \
    mkdir -p /usr/local/openresty/site/lualib/net \
    && \
    curl https://raw.githubusercontent.com/golgote/neturl/master/lib/net/url.lua -o /usr/local/openresty/site/lualib/net/url.lua \
    && \
    rm -rf /tmp/libvips \
    && \
    cd /tmp/helper-lib \
    && \
    touch * \
    && \
    make clean \
    && \
    make install \
    && \
    cd /tmp \
    && \
    rm -rf /tmp/helper-lib \
    && \
    ldconfig /usr/local/lib \
    && \
    apk del build-deps \
    && \
    rm -rf /var/cache/apk/*

COPY ./nginx.conf    /var/run/openresty-imaging/nginx.conf
COPY ./lib/resty/*   /usr/local/openresty/site/lualib/resty/

ENTRYPOINT [ "/bin/sh", "/entrypoint.sh" ]