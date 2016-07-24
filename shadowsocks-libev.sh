#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

shadowsocks_libev_ver="2.4.7"

yum install -y wget unzip openssl-devel gcc swig python python-devel python-setuptools autoconf libtool libevent xmlto
yum install -y automake make curl curl-devel zlib-devel openssl-devel perl perl-devel cpio expat-devel gettext-devel asciidoc

wget --no-check-certificate https://github.com/shadowsocks/shadowsocks-libev/archive/v${shadowsocks_libev_ver}.zip -O shadowsocks-libev-${shadowsocks_libev_ver}.zip
unzip shadowsocks-libev-${shadowsocks_libev_ver}.zip
cd shadowsocks-libev-${shadowsocks_libev_ver}
./configure
make && make install
