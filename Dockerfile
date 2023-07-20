FROM openresty/openresty:alpine

ENV LIBVIPS_VERSION 8.14.2

WORKDIR /tmp
EXPOSE 8080

RUN apk add --no-cache --virtual build-deps \
        gcc g++ make build-base curl perl \
    && \
    apk add --no-cache vips vips-dev

RUN /usr/local/openresty/bin/opm install pintsized/lua-resty-http \
    && \
    /usr/local/openresty/bin/opm install bungle/lua-resty-prettycjson \
    && \
    mkdir -p /usr/local/openresty/site/lualib/net \
    && \
    curl https://raw.githubusercontent.com/golgote/neturl/master/lib/net/url.lua -o /usr/local/openresty/site/lualib/net/url.lua

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

COPY ./entrypoint.sh /entrypoint.sh
COPY ./nginx.conf    /var/run/openresty-imaging/nginx.conf
COPY ./lib/resty/*   /usr/local/openresty/site/lualib/resty/

RUN mkdir -p /var/run/openresty-imaging/logs \
    && \
    chmod +x /entrypoint.sh



ENTRYPOINT [ "/bin/sh", "/entrypoint.sh" ]