#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Get version
function GetOSVersion(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else    
        grep -oE  "[0-9.]+" /etc/issue
    fi    
}

# CentOS version
function SystenVersion(){
    local code=$1
    local version="`GetOSVersion`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi        
}

function Install() {
    read -p "Which version do you want to install? (Default: 2.5.3)" VERSION
    [ -z "$VERSION" ] && VERSION="2.5.3"

    yum install -y wget unzip openssl-devel gcc swig python python-devel python-setuptools autoconf libtool libevent xmlto
    yum install -y automake make curl curl-devel zlib-devel openssl-devel perl perl-devel cpio expat-devel gettext-devel asciidoc pcre-devel

    wget --no-check-certificate https://github.com/shadowsocks/shadowsocks-libev/archive/v${VERSION}.zip -O shadowsocks-libev-${VERSION}.zip
    unzip shadowsocks-libev-${VERSION}.zip
    cd shadowsocks-libev-${VERSION}
    ./configure
    make && make install

    # TODO Check install result
    echo ""
    start
}

function Add() {
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

    Firewall ${PORT}

    nohup /usr/local/bin/ss-server -s ${IP} -p ${PORT} -k ${PASSWORD} -m aes-256-cfb >> /var/log/shadowsocks.log > /dev/null 2>&1 &
    echo "nohup /usr/local/bin/ss-server -s ${IP} -p ${PORT} -k ${PASSWORD} -m aes-256-cfb >> /var/log/shadowsocks.log &" >> /etc/rc.local

    echo ""
    echo -e "Your public IP is\t\033[32m$IP\033[0m"
    echo -e "Your Server Port is\t\033[32m$PORT\033[0m"
    echo -e "Your Password is\t\033[32m$PASSWORD\033[0m"
    echo -e "Your Encryption Method\t\033[32maes-256-cfb\033[0m"
    echo ""
}

function Firewall() {
    PORT=$1

    echo ""
    if SystenVersion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep '${PORT}' | grep 'ACCEPT' > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${PORT} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${PORT} -j ACCEPT
                service iptables save
                service iptables restart
            else
                echo "Port ${PORT} has been set up."
            fi
        else
            echo -e "\033[41;37m WARNING \033[0m iptables looks like shutdown or not installed, please manually set it if necessary."
        fi
    elif SystenVersion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ];then
            firewall-cmd --permanent --zone=public --add-port=${PORT}/tcp
            firewall-cmd --permanent --zone=public --add-port=${PORT}/udp
            firewall-cmd --reload
        else
            echo "Firewalld looks like not running, try to start..."
            systemctl start firewalld
            if [ $? -eq 0 ];then
                firewall-cmd --permanent --zone=public --add-port=${PORT}/tcp
                firewall-cmd --permanent --zone=public --add-port=${PORT}/udp
                firewall-cmd --reload
            else
                echo -e "\033[41;37m WARNING \033[0m Try to start firewalld failed. please enable port ${PORT} manually if necessary."
            fi
        fi
    fi
    echo "Firewall set completed..."
}

function start() {
    echo "which do you want to? Input the number and press enter."
    echo "1. Install"
    echo "2. Add port"
    echo "input other to exit"
    read num

    case "$num" in
    [1] ) (Install);;
    [2] ) (Add);;
    *) echo "";;
    esac
}

start
