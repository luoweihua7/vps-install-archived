#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

function Install() {
    read -p "Which version do you want to install? (Default: 2.4.7)" VERSION
    [ -z "$VERSION" ] && VERSION="2.4.7"

    yum install -y wget unzip openssl-devel gcc swig python python-devel python-setuptools autoconf libtool libevent xmlto
    yum install -y automake make curl curl-devel zlib-devel openssl-devel perl perl-devel cpio expat-devel gettext-devel asciidoc

    wget --no-check-certificate https://github.com/shadowsocks/shadowsocks-libev/archive/v${VERSION}.zip -O shadowsocks-libev-${VERSION}.zip
    unzip shadowsocks-libev-${VERSION}.zip
    cd shadowsocks-libev-${VERSION}
    ./configure
    make && make install

    echo ""
    Add
}

function Add() {
    echo "Add shadowsocks config"
    read -p "Please input password (Default: qwertyuiop):" PASSWORD
    [ -z "$PASSWORD" ] && PASSWORD="qwertyuiop"

    while true
    do
    read -p "Please input port number (Default: 8989):" PORT
    [ -z "$PORT" ] && PORT="8989"
    expr $PORT + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ $PORT -ge 1 ] && [ $PORT -le 65535 ]; then
            break
        else
            echo "Input error! Please input correct numbers."
        fi
    else
        echo "Input error! Please input correct numbers."
    fi
    done

    IP=`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk 'NR==1 { print $1}'`

    nohup /usr/local/bin/ss-server -s ${IP} -p ${PORT} -k ${PASSWORD} -m aes-256-cfb >> /var/log/shadowsocks.log > /dev/null 2>&1 &
    echo "nohup /usr/local/bin/ss-server -s ${IP} -p ${PORT} -k ${PASSWORD} -m aes-256-cfb >> /var/log/shadowsocks.log &" >> /etc/rc.local

    echo ""
    echo -e "Your public IP is\t\033[32m$IP\033[0m"
    echo -e "Your Server Port is\t\033[32m$PORT\033[0m"
    echo -e "Your Password is\t\033[32m$PASSWORD\033[0m"
    echo -e "Your Encryption Method\t\033[32maes-256-cfb\033[0m"
    echo ""
}

echo "which do you want to? Input the number and press enter."
echo "1. Install"
echo "2. Add port"
read num

case "$num" in
[1] ) (Install);;
[2] ) (Add);;
*) echo "";;
esac
