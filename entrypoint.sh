#!/bin/sh

# update certs
/usr/sbin/update-ca-certificates

# Generate resolver config for nginx 
echo resolver $(awk 'BEGIN{ORS=" "} $1=="nameserver" {print $2}' /etc/resolv.conf) " ipv6=off;" > /var/run/openresty-imaging/resolvers.conf

# Start openresty
exec \
    /usr/local/openresty/bin/openresty \
    -p /var/run/openresty-imaging \
    -c /var/run/openresty-imaging/nginx.conf