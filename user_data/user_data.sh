#!/bin/bash
# This script configures and enables a fresh server with nginx
# including the RTMP module and stunnel enabling live streaming
# to multiple sources including YouTube and Facebook.

# Set variables
# NGINX_VERSION="nginx-1.18.0"
# NGINX_RTMP_MODULE_VERSION="1.2.1"
# NGINX_CONF_PATH="/etc/nginx/nginx.conf"
# STUNNEL_CONF="/etc/stunnel/stunnel.conf"
# STUNNEL_DEBUG="7"
# STUNNEL_CLIENT="no"
# STUNNEL_CAFILE="/etc/ssl/certs/ca-certificates.crt"
# STUNNEL_VERIFY_CHAIN="no"
# STUNNEL_OPENSSL_CONF="/etc/stunnel/openssl.cnf"
# STUNNEL_KEY="/etc/stunnel/stunnel.key"
# STUNNEL_CRT="/etc/stunnel/stunnel.pem"
# STUNNEL_DELAY="no"
# YOUTUBE_KEY="[youtube_rtmp_stream_key]"
# FACEBOOK_KEY="[facebook_rtmp_stream_key]"

# setup logging and begin
set -e -u -o pipefail
NOW=$(date +"%FT%T")
echo "[$NOW]  Beginning user_data script."

sudo su

# update packages and install prereqs
apt-get -y update
apt-get upgrade -y
apt install -y jq awscli unzip
apt install -y python3-pip
pip3 install awscli --upgrade
apt-get install -y build-essential ca-certificates openssl libssl-dev stunnel

# Download and decompress Nginx
mkdir -p /tmp/build/nginx 
cd /tmp/build/nginx 
wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz 
tar -zxf ${NGINX_VERSION}.tar.gz

# Download and decompress RTMP module
mkdir -p /tmp/build/nginx-rtmp-module 
cd /tmp/build/nginx-rtmp-module 
wget -O nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz 
tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz 
cd nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}

# Build and install Nginx
# The default puts everything under /usr/local/nginx, so it's needed to change
# it explicitly. Not just for order but to have it in the PATH
cd /tmp/build/nginx/${NGINX_VERSION} 
./configure \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --pid-path=/run/nginx.pid \
    --lock-path=/var/lock/nginx/nginx.lock \
    --http-log-path=/var/log/nginx/access.log \
    --http-client-body-temp-path=/tmp/nginx-client-body \
    --with-http_ssl_module \
    --with-threads \
    --without-http_rewrite_module \
    --without-http_gzip_module \
    --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} 
make -j $(getconf _NPROCESSORS_ONLN) 
make install 
mkdir /var/lock/nginx
cp /tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}/stat.xsl /usr/local/nginx/html/
rm -rf /tmp/build

# create stunnel conf
cat > /etc/stunnel/openssl.cnf <<EOF
[ req ]
default_bits            = 2048
default_keyfile         = /etc/stunnel/stunnel.key
distinguished_name      = req_distinguished_name
prompt                  = no
policy                  = policy_anything

[ req_distinguished_name ]
commonName              = localhost
EOF

if [[ ! -f ${STUNNEL_KEY} ]]; then
    if [[ -f ${STUNNEL_CRT} ]]; then
        echo >&2 "crt (${STUNNEL_CRT}) missing key (${STUNNEL_KEY})"
        exit 1
    fi

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${STUNNEL_KEY} -out ${STUNNEL_CRT} \
        -config ${STUNNEL_OPENSSL_CONF} 
fi

cp -v ${STUNNEL_CAFILE} /usr/local/share/ca-certificates/stunnel-ca.crt
cp -v ${STUNNEL_CRT} /usr/local/share/ca-certificates/stunnel.crt
update-ca-certificates

# # create nginx conf
cat > ${NGINX_CONF_PATH} <<EOF
worker_processes 1;

error_log /var/log/nginx/error.log info;

events {
    worker_connections 1024;
}

rtmp {
    server {
        listen 1935;

        application live {
            live on;
            push rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_KEY};
            push rtmp://127.0.0.1:19350/rtmp/${FACEBOOK_KEY};
        }
    }
}

http {
        server {
        listen 8080;

        location / {
            root html;
        }

        location /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet stat.xsl;
        }

        location /stat.xsl {
            root html;
        }
    }
}
EOF

# create stunnel.conf
cat > ${STUNNEL_CONF} <<EOF
cert = /etc/stunnel/stunnel.pem
key = /etc/stunnel/stunnel.key

#setuid = stunnel
#setgid = stunnel

pid = /run/stunnel.pid

socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

CAfile = /etc/ssl/certs/ca-certificates.crt
verifyChain = yes
#sslVersionMin = TLSv1.2

debug = 1
output = /var/log/stunnel4/stunnel.log
foreground = no
client = no

[fb-live]
client = yes
accept = 127.0.0.1:19350
connect = live-api-s.facebook.com:443
EOF

# nginx Service
cat > /etc/systemd/system/nginx.service <<EOF
[Unit]
Description=A high performance web server and a reverse proxy server
After=network.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# Stunnel
cat > /etc/systemd/system/stunnel.service <<EOF
[Unit]
Description=A service roviding secure encrypted connections for clients without TLS or SSL.
After=network.target nginx.service

[Service]
Type=forking
PIDFile=/run/stunnel.pid
ExecStart=/usr/bin/stunnel ${STUNNEL_CONF}
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/stunnel.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nginx
systemctl enable stunnel

# end script
NOW=$(date +"%FT%T")
echo "[$NOW]  Finished user_data script."

reboot now