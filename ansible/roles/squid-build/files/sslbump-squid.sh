#!/bin/bash

#Create a SSL certificate for the SslBump Squid module
mkdir /etc/squid/ssl
cd /etc/squid/ssl
openssl genrsa -out squid.key 4096
openssl req -new -key squid.key -out squid.csr -subj "/C=UK/ST=LONDON/L=squid/O=squid/CN=squid"
openssl x509 -req -days 3650 -in squid.csr -signkey squid.key -out squid.crt
cat squid.key squid.crt >> squid.pem
chmod 600 squid.pem