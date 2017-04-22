FROM openresty/openresty:alpine

WORKDIR /tmp
EXPOSE 8080

COPY ./entrypoint.sh /entrypoint.sh

RUN apk add --no-cache --virtual build-deps \
        gcc g++ make libc-dev libtool tar gettext git gtk-doc build-base curl \
        glib-dev libpng-dev libwebp-dev libexif-dev libxml2-dev libjpeg-turbo-dev tiff-dev giflib-dev librsvg-dev poppler-dev \
    && \
    apk add --no-cache \
        glib libpng libwebp libexif libxml2 libjpeg-turbo tiff giflib librsvg ca-certificates libstdc++ libc6-compat poppler poppler-glib \
        fontconfig \
        font-bh-100dpi \
        font-sun-misc \
        font-bh-lucidatypewriter-100dpi \
        font-adobe-utopia-type1 \
        font-cronyx-cyrillic \
        font-misc-cyrillic \
        font-schumacher-misc \
        font-daewoo-misc \
        font-screen-cyrillic \
        font-adobe-utopia-75dpi \
        font-bitstream-100dpi \
        font-xfree86-type1 \
        font-bitstream-75dpi \
        font-bh-ttf \
        font-arabic-misc \
        font-dec-misc \
        font-misc-ethiopic \
        font-micro-misc \
        font-alias \
        font-isas-misc \
        font-bh-lucidatypewriter-75dpi \
        font-winitzki-cyrillic \
        font-jis-misc \
        ttf-ubuntu-font-family \
        font-bitstream-type1 \
        font-mutt-misc \
        font-misc-misc \
        font-adobe-100dpi \
        font-bh-type1 \
        font-bh-75dpi \
        font-sony-misc \
        font-ibm-type1 \
        font-bitstream-speedo \
        font-adobe-utopia-100dpi \
        font-adobe-75dpi \
        font-misc-meltho \
        font-cursor-misc \    
    && \
    curl -L https://github.com/jcupitt/libvips/releases/download/v8.5.3/vips-8.5.3.tar.gz | tar xz \
    && \
    cd vips-8.5.3 \
    && \
    CFLAGS="-O3 -g" ./configure --disable-python --without-gsf \
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
    rm -rf /tmp/vips-8.5.3

COPY ./helper-lib /tmp/helper-lib

RUN cd /tmp/helper-lib \
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