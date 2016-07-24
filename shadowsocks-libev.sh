#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

function installSS() {
    echo -e "Which version do you want to install?"
    read -p "(Default version: 2.4.7)" shadowsocks_libev_ver
    [ -z "$shadowsocks_libev_ver" ] && shadowsocks_libev_ver="2.4.7"

    yum install -y wget unzip openssl-devel gcc swig python python-devel python-setuptools autoconf libtool libevent xmlto
    yum install -y automake make curl curl-devel zlib-devel openssl-devel perl perl-devel cpio expat-devel gettext-devel asciidoc

    wget --no-check-certificate https://github.com/shadowsocks/shadowsocks-libev/archive/v${shadowsocks_libev_ver}.zip -O shadowsocks-libev-${shadowsocks_libev_ver}.zip
    unzip shadowsocks-libev-${shadowsocks_libev_ver}.zip
    cd shadowsocks-libev-${shadowsocks_libev_ver}
    ./configure
    make && make install

    adduser
}

function adduser() {
    echo "Please input password for shadowsocks-libev:"
    read -p "(Default password: qwertyuiop):" shadowsockspwd
    [ -z "$shadowsockspwd" ] && shadowsockspwd="qwertyuiop"

    while true
    do
    echo -e "Please input port for shadowsocks-libev [1-65535]:"
    read -p "(Default port: 8989):" shadowsocksport
    [ -z "$shadowsocksport" ] && shadowsocksport="8989"
    expr $shadowsocksport + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ $shadowsocksport -ge 1 ] && [ $shadowsocksport -le 65535 ]; then
            break
        else
            echo "Input error! Please input correct numbers."
        fi
    else
        echo "Input error! Please input correct numbers."
    fi
    done

    echo "Getting Public IP address"
    IP=`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk 'NR==1 { print $1}'`
    echo -e "Your main public IP is\t\033[32m$IP\033[0m"
    echo ""

    echo "nohup /usr/local/bin/ss-server -s ${IP} -p ${shadowsocksport} -k ${shadowsockspwd} -m aes-256-cfb &" >> /etc/rc.local
}

echo "which do you want to? Input the number."
echo "1. Install"
echo "2. Add port"
read num

case "$num" in
[1] ) (installSS);;
[2] ) (adduser);;
*) echo "bye bye";;
esac
