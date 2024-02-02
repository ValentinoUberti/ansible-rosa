#!/bin/bash
set -e -x

sudo dnf install -y wget curl python36 python36-devel net-tools gcc libffi-devel openssl-devel jq bind-utils podman squid

mkdir -p /etc/squid/certs/create
cd /etc/squid/certs/create

cat << EOF | sudo tee /etc/squid/squid.conf
acl localnet src 10.0.0.0/8	# RFC1918 possible internal network
acl localnet src 172.16.0.0/12	# RFC1918 possible internal network
acl localnet src 192.168.0.0/16	# RFC1918 possible internal network
acl localnet src fc00::/7       # RFC 4193 local private network range
acl localnet src fe80::/10      # RFC 4291 link-local (directly plugged) machines
acl SSL_ports port 443
acl Safe_ports port 80		# http
acl Safe_ports port 21		# ftp
acl Safe_ports port 443		# https
acl Safe_ports port 70		# gopher
acl Safe_ports port 210		# wais
acl Safe_ports port 1025-65535	# unregistered ports
acl Safe_ports port 280		# http-mgmt
acl Safe_ports port 488		# gss-http
acl Safe_ports port 591		# filemaker
acl Safe_ports port 777		# multiling http
acl CONNECT method CONNECT
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all
http_port 3128 ssl-bump \
  cert=/etc/squid/certs/squid-ca-cert-key.pem \
  generate-host-certificates=on dynamic_cert_mem_cache_size=16MB
https_port 3129 intercept ssl-bump \
  cert=/etc/squid/certs/squid-ca-cert-key.pem \
  generate-host-certificates=on dynamic_cert_mem_cache_size=16MB
sslcrtd_program /usr/lib64/squid/ssl_crtd -s /var/lib/ssl_db -M 16MB
acl step1 at_step SslBump1
ssl_bump peek step1
ssl_bump bump all
ssl_bump splice all
coredump_dir /var/spool/squid
refresh_pattern ^ftp:		1440	20%	10080
refresh_pattern ^gopher:	1440	0%	1440
refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
refresh_pattern .		0	20%	4320
EOF

sudo /usr/lib64/squid/ssl_crtd -c -s /var/lib/ssl_db
sudo chown squid:squid -R /var/lib/ssl_db

sudo systemctl enable squid
sudo systemctl start squid
