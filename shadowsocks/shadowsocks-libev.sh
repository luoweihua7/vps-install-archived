#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

conf_file_path="/home/conf/shadowsocks"
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

progressfilter ()
{
    local flag=false c count cr=$'\r' nl=$'\n'
    while IFS='' read -d '' -rn 1 c
    do
        if $flag
        then
            printf '%c' "$c"
        else
            if [[ $c != $cr && $c != $nl ]]
            then
                count=0
            else
                ((count++))
                if ((count > 1))
                then
                    flag=true
                fi
            fi
        fi
    done
}

function install_shadowsocks() {
    if sys_version 6; then
        wget -P /etc/yum.repos.d/ ${epel_centos6}
    elif sys_version 7; then
        yum install epel-release -y
        yum install gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel libsodium-devel mbedtls-devel -y
        wget -P /etc/yum.repos.d/ ${epel_centos7}
    fi

    yum install shadowsocks-libev -y

    echo "Downloading shadowsocks startup script."
    wget --no-check-certificate --progress=bar:force https://github.com/luoweihua7/vps-install/raw/master/shadowsocks/shadowsocks.d.sh -O /etc/init.d/shadowsocks 2>&1 | progressfilter
    chmod 755 /etc/init.d/shadowsocks
    echo "Configuring startup script."
    chkconfig --add shadowsocks
    chkconfig shadowsocks on

    echo ""
    echo -e "\033[42;37m SUCCESS \033[0m Shadowsocks installed."
    start
}

function add_service() {
    default_password=`fun_randstr`
    default_port=`random 10000 60000`

    echo ""
    read -p "Please input password (Default: $default_password): " PASSWORD
    [ -z "$PASSWORD" ] && PASSWORD=$default_password

    while true
    do
    echo ""
    read -p "Please input port number (Default: $default_port): " PORT
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
    read -p "Enter your choice (1, 2, 3, 4 or 5. default [3]) " ENCRYPT
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
            ENCRYPT="aes-256-cfb"
            ;;
    esac

    shadowsocks_config_file="$conf_file_path/conf.$PORT.json"

    if [ ! -s "$shadowsocks_config_file" ]; then
        LOCALIP="0.0.0.0"

        config_shadowsocks $PORT $PASSWORD $ENCRYPT $shadowsocks_config_file
        add_firewall ${PORT}

        # start up
        nohup /usr/bin/ss-server -c $shadowsocks_config_file > /dev/null 2>&1 &

        echo ""
        # echo -e "Your public IP is\t\033[32m$LOCALIP\033[0m"
        echo -e "Your Server Port is\t\033[32m$PORT\033[0m"
        echo -e "Your Password is\t\033[32m$PASSWORD\033[0m"
        echo -e "Your Encryption Method\t\033[32m$ENCRYPT\033[0m"
        echo ""
        echo -e "\033[42;37m SUCCESS \033[0m Service added."
        echo ""
    else
        echo ""
        echo -e "\033[41;37m ERROR \033[0m Port $PORT already in use."
        add_service
    fi
}

function add_firewall() {
    PORT=$1

    echo ""
    echo "Configuring iptables..."

    echo ""
    if sys_version 6; then
        # check iptables is installed
        iptables_installed=`rpm -qa | grep iptables | wc -l`
        if [ $iptables_installed -ne 0 ]; then
            # check port is in use
            is_port_in_use=`iptables -nL | grep "\:$PORT\b" | wc -l`
            if [ $is_port_in_use -eq 0 ]; then
                iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
                iptables -I INPUT -p udp --dport $PORT -j ACCEPT
                service iptables save > /dev/null

                # check is iptable start
                is_iptables_started=`iptables -vL | grep "\b:\b" | awk '{split($NF,a,":");print a[2]}' | wc -l`
                if [ $is_iptables_started -ne 0 ]; then
                    service iptables restart > /dev/null
                else
                    echo -e "\033[41;37m WARNING \033[0m iptables looks like shutdown, please manually set it if necessary."
                fi
            else
                echo "Port $PORT has been set up."
            fi
        else
            echo -e "\033[41;37m WARNING \033[0m iptables looks like not installed, please manually set it if necessary."
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
                echo -e "\033[41;37m WARNING \033[0m Try to start firewalld failed. please manually set it if necessary."
            fi
        fi
    fi

    echo "Iptables setup completed..."
}

function config_shadowsocks() {
	# port,password,encryption-method
    mkdir $conf_file_path -p

    cat > ${4}<<-EOF
{
    "server":"0.0.0.0",
    "server_port":${1},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${2}",
    "timeout":600,
    "method":"${3}"
}
EOF
}

function remove_service() {
    default_del_port="0"

    while true
    do
    echo ""
    read -p "Please input port number you want to remove: " DELPORT
    [ -z "$DELPORT" ] && DELPORT=$default_del_port
    expr $DELPORT + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ $DELPORT -ge 1 ] && [ $DELPORT -le 65535 ]; then
            break
        else
            echo "Input error! Please input correct numbers."
        fi
    else
        echo "Input error! Please input correct numbers."
    fi
    done

    del_port_file="$conf_file_path/conf.$DELPORT.json"

    if [ ! -s $del_port_file ]; then
        echo "$DELPORT not used."
        echo ""
        remove_service
    else
        echo "Killing process..."
        delpid=`ps aux | grep "$del_port_file" | grep -v "grep" | awk '{print $2}'`
        if [ ! $delpid ]; then
            echo "Shadowsocks process list:"
            ps aux | grep "ss-server" | grep -v "grep"
            echo ""
            echo "Related processes not found ($del_port_file)."
        else 
            if ps -p $delpid > /dev/null ; then
                kill -9 $delpid
            fi
        fi

        echo "Removing config file..."
        rm -rf $del_port_file
        echo "Configuring firewall..."
        iptables_installed=`rpm -qa | grep iptables | wc -l`
        if [ $iptables_installed -ne 0 ]; then
            iptables -D INPUT -p tcp --dport $DELPORT -j ACCEPT
            iptables -D INPUT -p udp --dport $DELPORT -j ACCEPT
            service iptables save > /dev/null
        else
            echo -e "\033[41;37m WARNING \033[0m iptables looks like not installed."
        fi

        echo -e "\033[42;37m SUCCESS \033[0m Service removed, all done."
        echo ""
    fi
}

function start() {
    echo ""
    echo "Which do you want to do?"
    echo "1. Install"
    echo "2. Add port"
    echo "3. Remove port"
    read -p "Input the number and press enter. (Press any other key to exit) " num

    case "$num" in
        [1] ) (install_shadowsocks);;
        [2] ) (add_service);;
        [3] ) (remove_service);;
        *) echo "Bye~~~";;
    esac
}

start
