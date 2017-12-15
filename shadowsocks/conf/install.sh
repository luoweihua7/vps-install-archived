#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

CONF_PATH="/home/conf/shadowsocks"
SRC_PATH="/home/github/"
PROJ_NAME="shadowsocks-manager"

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

function install_manager() {
    mkdir -p ${SRC_PATH}
    mkdir -p ${CONF_PATH}

    echo "Start download source code..."
    git clone https://github.com/shadowsocks/shadowsocks-manager.git ${SRC_PATH}
    cd ${SRC_PATH}${PROJ_NAME}
    npm i
    echo "Souce code download completed."
}

function download_conf() {
    echo "Start download config files..."
    wget -N -P ${CONF_PATH} https://github.com/luoweihua7/vps-install/raw/master/shadowsocks/conf/app.conf.json
    wget -N -P ${CONF_PATH} https://github.com/luoweihua7/vps-install/raw/master/shadowsocks/conf/shadowsocks-libev.yml
    wget -N -P ${CONF_PATH} https://github.com/luoweihua7/vps-install/raw/master/shadowsocks/conf/webui.yml
    echo "Config download completed."

    default_ss_port=`random 10000 60000`
    default_ss_manager_password=`fun_randstr`
    default_ss_manager_port=`random 10000 60000`
    default_web_port="8080"
    
    echo ""
    read -p "Please input shadowsocks port (Default: $default_ss_port):" SSPORT
    [ -z "$SSPORT" ] && SSPORT=$default_ss_port

    echo ""
    read -p "Please input ss-manager password (Default: $default_ss_manager_password):" SMPASSWD
    [ -z "$SMPASSWD" ] && SMPASSWD=$default_ss_manager_password

    echo ""
    read -p "Please input ss-manager port (Default: $default_ss_manager_port):" SMPORT
    [ -z "$SMPORT" ] && SMPORT=$default_ss_manager_port

    echo ""
    read -p "Please input webui port (Default: $default_web_port):" WEBPORT
    [ -z "$WEBPORT" ] && WEBPORT=$default_web_port

    while true
        do
        echo ""
        read -p "Please input email username[@outlook.com] (username ONLY!!!):" EMAILADDR
        if [ ! -n "${EMAILADDR}" ]; then
            echo "Input error! Please input correct username."
        else
            break
        fi
    done

    while true
        do
        echo ""
        read -p "Please input outlook email password:" EMAILPASSWD
        if [ ! -n "${EMAILPASSWD}" ]; then
            echo "Input error! Please input correct password."
        else
            break
        fi
    done

    sed -i "s#SSPORT#${SSPORT}#g" ${CONF_PATH}/shadowsocks-libev.yml
    sed -i "s#SMPORT#${SMPORT}#g" ${CONF_PATH}/shadowsocks-libev.yml
    sed -i "s#SMPASSWD#${SMPASSWD}#g" ${CONF_PATH}/shadowsocks-libev.yml

    sed -i "s#SMPORT#${SMPORT}#g" ${CONF_PATH}/webui.yml
    sed -i "s#SMPASSWD#${SMPASSWD}#g" ${CONF_PATH}/webui.yml
    sed -i "s#EMAILADDR#${EMAILADDR}#g" ${CONF_PATH}/webui.yml
    sed -i "s#EMAILPASSWD#${EMAILPASSWD}#g" ${CONF_PATH}/webui.yml
    sed -i "s#WEBPORT#${WEBPORT}#g" ${CONF_PATH}/webui.yml

    sed -i "s#APPCWD#${SRC_PATH}${PROJ_NAME}#g" ${CONF_PATH}/app.conf.json
    sed -i "s#CONF_PATH#${CONF_PATH}#g" ${CONF_PATH}/app.conf.json
}

function install_deps(){
    npm config set unsafe-perm=true
    npm i pm2 -g
}

function startup() {
    pm2 start /home/conf/shadowsocks/app.config.json
}

function install_all(){
    install_deps
    install_manager
    download_conf
    startup
}

install_all
