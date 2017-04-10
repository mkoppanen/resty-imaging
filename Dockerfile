FROM openresty/openresty:xenial

WORKDIR /tmp
EXPOSE 8080

COPY ./entrypoint.sh /entrypoint.sh

RUN apt-get update \
    && \
    apt-get -y dist-upgrade \
    && \
    apt-get install -y \
        build-essential \
        pkg-config \
        glib2.0-dev \
        libxml2-dev \
        gtk-doc-tools \
        libpng-dev \
        libjpeg-turbo8-dev \
        libtiff-dev \
        libgif-dev \
        gobject-introspection \
        git \
        libexif-dev \
        libwebp-dev \
        librsvg2-dev \
        graphicsmagick \
    && \
    git clone https://github.com/jcupitt/libvips.git \
    && \
    cd libvips \
    && \
    CFLAGS="-O3 -g" ./autogen.sh --disable-python \
    && \
    make -j8 \
    && \
    make install \
    && \
    ldconfig \
    && \
    mkdir -p /var/run/openresty-imaging/logs \
    && \
    chmod +x /entrypoint.sh \
    && \
    /usr/local/openresty/bin/opm install pintsized/lua-resty-http \
    && \
    /usr/local/openresty/bin/opm install bungle/lua-resty-prettycjson \
    && \
    /usr/local/openresty/luajit/bin/luarocks install net-url \
    && \
    /usr/local/openresty/luajit/bin/luarocks install inspect

COPY ./nginx.conf   /var/run/openresty-imaging/nginx.conf
COPY ./lib/resty/*  /usr/local/openresty/site/lualib/resty/

COPY ./helper-lib  /tmp/helper-lib
RUN cd /tmp/helper-lib \
    && \
    touch * \
    && \
    make clean \
    && \
    make install


ENTRYPOINT [ "/bin/sh", "/entrypoint.sh" ]