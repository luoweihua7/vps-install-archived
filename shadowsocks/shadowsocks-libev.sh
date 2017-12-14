#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

epel_centos6="https://copr.fedorainfracloud.org/coprs/librehat/shadowsocks/repo/epel-6/librehat-shadowsocks-epel-6.repo"
epel_centos7="https://copr.fedorainfracloud.org/coprs/librehat/shadowsocks/repo/epel-7/librehat-shadowsocks-epel-7.repo"

# Get version
function get_os_version(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else    
        grep -oE  "[0-9.]+" /etc/issue
    fi    
}

# CentOS version
function sys_version(){
    local code=$1
    local version="`get_os_version`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi        
}

function fun_randstr(){
  index=0
  strRandomPass=""
  for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {1..16}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
  echo $strRandomPass
}

function random(){  
    min=$1  
    max=$(($2-$min+1))  
    num=$(($RANDOM+1000000000))  
    echo $(($num%$max+$min))  
}

function add_service() {
    default_password=`fun_randstr`
    default_port=`random 10000 60000`

    echo ""
    read -p "Please input password (Default: $default_password):" PASSWORD
    [ -z "$PASSWORD" ] && PASSWORD=$default_password

    while true
    do
    echo ""
    read -p "Please input port number (Default: $default_port):" PORT
    [ -z "$PORT" ] && PORT=$default_port
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

    # set shadowsocks encrypt mode
    echo ""
    echo "Please select shadowsocks encrypt mode"
    echo "1: rc4-md5"
    echo "2: aes-128-cfb"
    echo "3: aes-256-cfb"
    echo "4: chacha20"
    echo "5: chacha20-ietf"
    read -p "Enter your choice (1, 2, 3, 4 or 5. default [4]) " ENCRYPT
    case "$ENCRYPT" in
        1)
            ENCRYPT="rc4-md5"
            ;;
        2)
            ENCRYPT="aes-128-cfb"
            ;;
        3)
            ENCRYPT="aes-256-cfb"
            ;;
        4)
            ENCRYPT="chacha20"
            ;;
        5)
            ENCRYPT="chacha20-ietf"
            ;;
        *)
            ENCRYPT="chacha20"
            ;;
    esac

    LOCALIP="0.0.0.0"

    add_firewall ${PORT}

    nohup /usr/bin/ss-server -s $LOCALIP -p $PORT -k $PASSWORD -m $ENCRYPT >> /var/log/shadowsocks.log > /dev/null 2>&1 &
    echo "nohup /usr/bin/ss-server -s $LOCALIP -p $PORT -k $PASSWORD -m $ENCRYPT >> /var/log/shadowsocks.log > /dev/null 2>&1 & " >> /etc/rc.local

    echo ""
    echo -e "Your public IP is\t\033[32m$LOCALIP\033[0m"
    echo -e "Your Server Port is\t\033[32m$PORT\033[0m"
    echo -e "Your Password is\t\033[32m$PASSWORD\033[0m"
    echo -e "Your Encryption Method\t\033[32m$ENCRYPT\033[0m"
    echo ""
}

function add_firewall() {
    PORT=$1

    echo ""
    if sys_version 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep '$PORT' | grep 'ACCEPT' > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
                iptables -I INPUT -p udp --dport $PORT -j ACCEPT
                service iptables save
                service iptables restart
            else
                echo "Port $PORT has been set up."
            fi
        else
            echo -e "\033[41;37m WARNING \033[0m iptables looks like shutdown or not installed, please manually set it if necessary."
        fi
    elif sys_version 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ];then
            firewall-cmd --permanent --zone=public --add-port=$PORT/tcp
            firewall-cmd --permanent --zone=public --add-port=$PORT/udp
            firewall-cmd --reload
        else
            echo "Firewalld looks like not running, try to start..."
            systemctl start firewalld
            if [ $? -eq 0 ];then
                firewall-cmd --permanent --zone=public --add-port=$PORT/tcp
                firewall-cmd --permanent --zone=public --add-port=$PORT/udp
                firewall-cmd --reload
            else
                echo -e "\033[41;37m WARNING \033[0m Try to start firewalld failed. please enable port $PORT manually if necessary."
            fi
        fi
    fi
    echo "Firewall set completed..."
}

function install_shadowsocks() {
    if sys_version 6; then
        wget -P /etc/yum.repos.d/ ${epel_centos6}
    elif sys_version 7; then
        wget -P /etc/yum.repos.d/ ${epel_centos7}
    fi

    yum install shadowsocks-libev -y

    echo ""
    start
}

function start() {
    echo ""
    echo "Which do you want to? Input the number and press enter. (Ctrl + C to exit)"
    echo "1. Install"
    echo "2. Add port"
    read num

    case "$num" in
    [1] ) (install_shadowsocks);;
    [2] ) (add_service);;
    *) echo "";;
    esac
}

start
