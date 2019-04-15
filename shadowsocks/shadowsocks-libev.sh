#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

conf_file_path="/home/conf/shadowsocks"
epel_centos6="https://copr.fedorainfracloud.org/coprs/librehat/shadowsocks/repo/epel-6/librehat-shadowsocks-epel-6.repo"
epel_centos7="https://copr.fedorainfracloud.org/coprs/librehat/shadowsocks/repo/epel-7/librehat-shadowsocks-epel-7.repo"

libsodium_file="libsodium-1.0.16"
libsodium_url="https://github.com/jedisct1/libsodium/releases/download/1.0.16/${libsodium_file}.tar.gz"
mbedtls_file="mbedtls-2.13.0"
mbedtls_url="https://tls.mbed.org/download/${mbedtls_file}-gpl.tgz"
cur_dir=`pwd`
old_version="2.5.5"

# Is need github private access token, 0:no, 1:yes
is_need_token="1"
private_token=""

# Colors (copy from teddysun)
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Get version
get_os_version(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

# CentOS version
sys_version(){
    local code=$1
    local version="`get_os_version`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi        
}

fun_randstr(){
    index=0
    strRandomPass=""
    for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {1..16}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
    echo $strRandomPass
}

# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# check kernel version for fast open
version_gt(){
    test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"
}
check_kernel_version(){
    local kernel_version=$(uname -r | cut -d- -f1)
    if version_gt ${kernel_version} 3.7.0; then
        return 0
    else
        return 1
    fi
}
check_kernel_headers(){
    if rpm -qa | grep -q headers-$(uname -r); then
        return 0
    else
        return 1
    fi
}

# copy from teddysun
download() {
    local filename=${1}
    local cur_dir=`pwd`
    local need_token=${3}
    [ ! "$(command -v wget)" ] && yum install -y -q wget

    if [ "$need_token" == "1" ] && [ -z ${private_token} ]; then
        while true
        do
        read -p $'[\e\033[0;32mINFO\033[0m] Input Github repo Access Token please: ' access_token
        if [ -z ${access_token} ]; then
            echo -e "\033[41;37m ERROR \033[0m Access Token required!!!"
            continue
        fi
        private_token=${access_token}
        break
        done
    fi

    if [ -s ${filename} ]; then
        echo -e "[${green}INFO${plain}] ${filename} already exists."
    else
        echo -e "[${green}INFO${plain}] ${filename} downloading now, Please wait..."
        if [ "${need_token}" == "1" ]; then
            wget --header="Authorization: token ${private_token}" --no-check-certificate -cq -t3 ${2} -O ${1}
        else
            wget --no-check-certificate -cq -t3 ${2} -O ${1}
        fi
        if [ $? -eq 0 ]; then
            echo -e "[${green}INFO${plain}] ${filename} download completed..."
        else
            echo -e "\033[41;37m ERROR \033[0m Failed to download ${filename}, please download it to ${cur_dir} directory manually and try again."
            echo -e "Download link: ${2}"
            exit 1
        fi
    fi
}

# copy from teddysun
install_libsodium() {
    if [ ! -f /usr/lib/libsodium.a ]; then
        cd ${cur_dir}
        download "${libsodium_file}.tar.gz" "${libsodium_url}"
        tar zxf ${libsodium_file}.tar.gz
        cd ${libsodium_file}
        ./configure --prefix=/usr && make && make install
        if [ $? -ne 0 ]; then
            echo -e "\033[41;37m ERROR \033[0m ${libsodium_file} install failed."
            exit 1
        else
            echo -e "[${green}INFO${plain}] ${libsodium_file} installed."
        fi

        cd ${cur_dir}
        rm -rf ${libsodium_file}*
    else
        echo -e "[${green}INFO${plain}] ${libsodium_file} already installed."
    fi
}
# copy from teddysun
install_mbedtls() {
    if [ ! -f /usr/lib/libmbedtls.a ]; then
        cd ${cur_dir}
        download "${mbedtls_file}-gpl.tgz" "${mbedtls_url}"
        tar xf ${mbedtls_file}-gpl.tgz
        cd ${mbedtls_file}
        make SHARED=1 CFLAGS=-fPIC
        make DESTDIR=/usr install
        if [ $? -ne 0 ]; then
            echo -e "\033[41;37m ERROR \033[0m ${mbedtls_file} install failed."
            exit 1
        else
            echo -e "[${green}INFO${plain}] ${mbedtls_file} installed."
        fi

        cd ${cur_dir}
        rm -rf ${mbedtls_file}*
    else
        echo -e "[${green}INFO${plain}] ${mbedtls_file} already installed."
    fi
}

install_shadowsocks(){
    disable_selinux

    echo ""
    echo "Which shadowsocks-libev version do you want to install? (If install failure, try another)"
    echo "1. Latest github version"
    echo "2. Newest rpm version"
    echo "3. Old github version (stable v2.5.5)"
    read -p "Input the number and press enter. (Default: [1], press any other key to exit) " num
    [ -z ${num} ] && num="1"

    case "$num" in
        [1] ) (install_shadowsocks_latest);;
        [2] ) (install_shadowsocks_rpm);;
        [3] ) (install_shadowsocks_old_version);;
        *) echo "Bye~~~";;
    esac
}

install_shadowsocks_rpm() {
    if sys_version 6; then
        wget -P /etc/yum.repos.d/ ${epel_centos6}
    elif sys_version 7; then
        yum install epel-release -y
        yum install gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel libsodium-devel mbedtls-devel -y
        wget -P /etc/yum.repos.d/ ${epel_centos7}
    fi

    yum install shadowsocks-libev -y

    install_shadowsocks_script

    echo ""
    echo -e "\033[42;37m SUCCESS \033[0m Shadowsocks installed."
    start
}

install_shadowsocks_latest() {
    # Install necessary dependencies (copy from teddysun)
    echo -e "[${green}INFO${plain}] Checking the EPEL repository..."
    if [ ! -f /etc/yum.repos.d/epel.repo ]; then
        yum install -y -q epel-release
    fi

    [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "\033[41;37m ERROR \033[0m Install EPEL repository failed, please check it." && exit 1
    [ ! "$(command -v yum-config-manager)" ] && yum install -y -q yum-utils
    if [ x"`yum-config-manager epel | grep -w enabled | awk '{print $3}'`" != x"True" ]; then
        yum-config-manager --enable epel
    fi
    echo -e "[${green}INFO${plain}] Install necessary dependencies..."
    yum install -y -q unzip openssl openssl-devel gettext gcc autoconf libtool automake make asciidoc xmlto libev-devel pcre pcre-devel git c-ares-devel

    # Other dependencies
    install_libsodium
    install_mbedtls
    ldconfig

    # copy from teddysun
    echo -e "[${green}INFO${plain}] Starting install latest shadowsocks-libev..."
    ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep 'tag_name' | cut -d\" -f4)
    [ -z ${ver} ] && echo -e "\033[41;37m ERROR \033[0m Get shadowsocks-libev latest version failed" && exit 1
    shadowsocks_libev_ver="shadowsocks-libev-$(echo ${ver} | sed -e 's/^[a-zA-Z]//g')"
    download_link="https://github.com/shadowsocks/shadowsocks-libev/releases/download/${ver}/${shadowsocks_libev_ver}.tar.gz"
    shadowsocks_libev_file="${shadowsocks_libev_ver}.tar.gz"

    download "${shadowsocks_libev_file}" "${download_link}"
    tar -zxf ${shadowsocks_libev_file}

    cd ${shadowsocks_libev_ver}
    ./configure --prefix=/usr --disable-documentation
    make && make install

    cd ..
    rm -rf ${shadowsocks_libev_ver}*

    install_shadowsocks_script

    echo ""
    echo -e "\033[42;37m SUCCESS \033[0m Shadowsocks installed."
    start
}

install_shadowsocks_old_version() {
    # read -p "Which version do you want to install? (Default: 2.5.5)" old_version
    # [ -z "$old_version" ] && old_version="2.5.5"

    echo -e "[${green}INFO${plain}] Installing shadowsocks-libev v${old_version}"
    yum install -y wget unzip openssl-devel gcc swig python python-devel python-setuptools autoconf libtool libevent xmlto
    yum install -y automake make curl curl-devel zlib-devel openssl-devel perl perl-devel cpio expat-devel gettext-devel asciidoc pcre-devel

    download "shadowsocks-libev-$old_version.tar.gz" "https://github.com/shadowsocks/shadowsocks-libev/archive/v$old_version.tar.gz"
    tar -zxf shadowsocks-libev-$old_version.tar.gz
    cd shadowsocks-libev-$old_version
    ./configure --prefix=/usr
    make && make install

    cd ..
    rm -rf shadowsocks-libev-$old_version*

    install_shadowsocks_script

    echo ""
    echo -e "\033[42;37m SUCCESS \033[0m Shadowsocks installed."
    start
}

install_shadowsocks_script() {
    echo ""
    echo -e "[${green}INFO${plain}] Downloading shadowsocks startup script."
    download "/etc/init.d/shadowsocks" "https://raw.githubusercontent.com/luoweihua7/vps-install/master/shadowsocks/shadowsocks.d.sh" "${is_need_token}"
    chmod 755 /etc/init.d/shadowsocks
    echo -e "[${green}INFO${plain}] Configuring startup script."
    chkconfig --add shadowsocks
    chkconfig shadowsocks on
    echo -e "[${green}INFO${plain}] Startup script setup completed."
}

add_service() {
    default_password=`fun_randstr`
    default_port=$(shuf -i 10000-39999 -n 1)

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
            echo -e "\033[41;37m ERROR \033[0m Input error! Please input correct numbers."
        fi
    else
        echo -e "\033[41;37m ERROR \033[0m Input error! Please input correct numbers."
    fi
    done

    echo ""
    read -p "Please input password (Default: $default_password): " PASSWORD
    [ -z "$PASSWORD" ] && PASSWORD=$default_password

    # set shadowsocks encrypt mode
    ciphers=(
        aes-256-cfb
        aes-192-cfb
        aes-128-cfb
        aes-256-gcm
        aes-192-gcm
        aes-128-gcm
        aes-256-ctr
        aes-192-ctr
        aes-128-ctr
        camellia-128-cfb
        camellia-192-cfb
        camellia-256-cfb
        xchacha20-ietf-poly1305
        chacha20-ietf-poly1305
        chacha20-ietf
        chacha20
        salsa20
        rc4-md5
    )
    while true
    do
    echo -e "Please select stream cipher for shadowsocks-libev:"
    for ((i=1;i<=${#ciphers[@]};i++ )); do
        hint="${ciphers[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    read -p "Which cipher you'd select(Default: ${ciphers[0]}):" pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "\033[41;37m ERROR \033[0m Please enter a number"
        continue
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#ciphers[@]} ]]; then
        echo -e "\033[41;37m ERROR \033[0m Please enter a number between 1 and ${#ciphers[@]}"
        continue
    fi
    ENCRYPT=${ciphers[$pick-1]}
    break
    done

    shadowsocks_config_file="$conf_file_path/conf.$PORT.json"

    if [ ! -s "$shadowsocks_config_file" ]; then
        LOCALIP="0.0.0.0"

        config_shadowsocks $PORT $PASSWORD $ENCRYPT $shadowsocks_config_file
        add_firewall ${PORT}

        # start up
        nohup /usr/bin/ss-server -u -c $shadowsocks_config_file > /dev/null 2>&1 &

        echo ""
        # echo -e "Your public IP is\t\033[32m$LOCALIP\033[0m"
        echo -e "Your Server Port is\t\033[32m$PORT\033[0m"
        echo -e "Your Password is\t\033[32m$PASSWORD\033[0m"
        echo -e "Your Encryption Method\t\033[32m$ENCRYPT\033[0m"
        echo ""
        echo -e "\033[42;37m SUCCESS \033[0m Config file created..."
        echo -e "\033[42;37m SUCCESS \033[0m Service has started..."
        echo ""
    else
        echo ""
        echo -e "\033[41;37m ERROR \033[0m Port $PORT already in use."
        add_service
    fi
}

add_firewall() {
    PORT=$1

    echo -e "[${green}INFO${plain}] Configuring firewall..."

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
                echo -e "[${green}INFO${plain}] Port $PORT has been set up."
            fi
        else
            echo -e "\033[41;37m WARNING \033[0m iptables looks like not installed, please manually set it if necessary."
        fi
    elif sys_version 7; then
        firewalld_installed=`rpm -qa | grep firewalld | wc -l`
        if [ $firewalld_installed -ne 0 ]; then
            systemctl status firewalld > /dev/null 2>&1
            if [ $? -eq 0 ];then
                firewall-cmd --permanent --zone=public --add-port=$PORT/tcp -q
                firewall-cmd --permanent --zone=public --add-port=$PORT/udp -q
                firewall-cmd --reload -q
            else
                echo -e "[${green}INFO${plain}] Firewalld looks like not running, try to start..."
                systemctl start firewalld -q
                if [ $? -eq 0 ];then
                    firewall-cmd --permanent --zone=public --add-port=$PORT/tcp -q
                    firewall-cmd --permanent --zone=public --add-port=$PORT/udp -q
                    firewall-cmd --reload -q
                else
                    echo -e "\033[41;37m WARNING \033[0m Try to start firewalld failed. please manually set it if necessary."
                fi
            fi
        else
            echo -e "\033[41;37m WARNING \033[0m Firewalld looks like not installed, please manually set it if necessary."
        fi
    fi

    echo -e "[${green}INFO${plain}] Firewall setup completed..."
}

config_shadowsocks() {
	# port,password,encryption-method
    mkdir $conf_file_path -p

    if check_kernel_version && check_kernel_headers; then
        fast_open="true"
    else
        fast_open="false"
    fi

    cat > ${4}<<-EOF
{
    "server":"0.0.0.0",
    "server_port":${1},
    "local_address":"0.0.0.0",
    "local_port":1080,
    "password":"${2}",
    "timeout":300,
    "fast_open":${fast_open},
    "method":"${3}",
    "mode":"tcp_and_udp"
}
EOF

    echo ""
    echo -e "[${green}INFO${plain}] Shadowsocks config file created."
}

remove_service() {
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
            echo -e "\033[41;37m ERROR \033[0m Input error! Please input correct numbers."
        fi
    else
        echo -e "\033[41;37m ERROR \033[0m Input error! Please input correct numbers."
    fi
    done

    del_port_file="$conf_file_path/conf.$DELPORT.json"

    if [ ! -s $del_port_file ]; then
        echo "$DELPORT not used."
        echo ""
        remove_service
    else
        echo -e "[${green}INFO${plain}] Killing process..."
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

        echo -e "[${green}INFO${plain}] Removing config file..."
        rm -rf $del_port_file
        echo -e "[${green}INFO${plain}] Configuring firewall..."
        if sys_version 6; then
            iptables_installed=`rpm -qa | grep iptables | wc -l`
            if [ $iptables_installed -ne 0 ]; then
                iptables -D INPUT -p tcp --dport $DELPORT -j ACCEPT
                iptables -D INPUT -p udp --dport $DELPORT -j ACCEPT
                service iptables save > /dev/null
            else
                echo -e "\033[41;37m WARNING \033[0m iptables looks like not installed."
            fi
        elif sys_version 7; then
            firewalld_installed=`rpm -qa | grep firewalld | wc -l`
            if [ $firewalld_installed -ne 0 ]; then
                systemctl status firewalld > /dev/null 2>&1
                if [ $? -eq 0 ];then
                    firewall-cmd --permanent --zone=public --remove-port=$DELPORT/tcp -q
                    firewall-cmd --permanent --zone=public --remove-port=$DELPORT/udp -q
                    firewall-cmd --reload -q
                else
                    # start firewalld to remove port
                    systemctl start firewalld -q
                    if [ $? -eq 0 ];then
                        firewall-cmd --permanent --zone=public --remove-port=$DELPORT/tcp -q
                        firewall-cmd --permanent --zone=public --remove-port=$DELPORT/udp -q
                        firewall-cmd --reload -q
                    fi
                    # reset firewall status
                    systemctl stop firewalld -q
                fi
            else
                echo -e "\033[41;37m WARNING \033[0m Firewalld looks like not installed."
            fi
        fi

        echo -e "\033[42;37m SUCCESS \033[0m Service removed, all done."
        echo ""
    fi
}

start() {
    echo ""
    echo "Which one do you want to do?"
    echo "1. Install shadowsocks-libev"
    echo "2. Add shadowsocks port"
    echo "3. Remove shadowsocks port"
    read -p "Input the number and press enter. (Press any other key to exit) " num

    case "$num" in
        [1] ) (install_shadowsocks);;
        [2] ) (add_service);;
        [3] ) (remove_service);;
        *) echo "Bye~~~";;
    esac
}

start
