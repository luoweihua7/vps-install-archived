#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Is need github private access token, 0:no, 1:yes
is_need_token="0"
private_token=""

# Color
red='\033[41;37m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
blue_bg='\033[44;37m'
plain='\033[0m'

# Message
INFO="${green}[INFO]${plain}"
WARN="${yellow}[WARN]${plain}"
ERROR="${red}[ERROR]${plain}"
SUCCESS="${green}[SUCCESS]${plain}"
READ_INFO=$'\e[31m[INFO]\e[0m'

ARIA_CONF_DIR="/usr/local/etc"

function get_os_version() {
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else    
        grep -oE  "[0-9.]+" /etc/issue
    fi    
}

function sys_version() {
    local code=$1
    local version="`get_os_version`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi
}

function install_aria2c() {
    echo ""
    mkdir ${ARIA_CONF_DIR}/aria2 -p
    mkdir /data/downloads -p
    mkdir /data/www -p

    if [ "${is_need_token}" == "1" ] && [ -z ${private_token} ]; then
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

    echo "Downloading aria2 package file, please wait..."
    if [ "${is_need_token}" == "1" ]; then
        # wget --header="Authorization: token ${private_token}" --no-check-certificate https://raw.githubusercontent.com/luoweihua7/vps-install/master/aria2/aria2.tar.gz -O /tmp/aria2.tar.gz >> /dev/null 2>&1
        curl -# -o /tmp/aria2.tar.gz -L https://raw.githubusercontent.com/luoweihua7/vps-install/master/aria2/aria2.tar.gz -H "Authorization: token ${private_token}"
    else
        # wget --no-check-certificate https://raw.githubusercontent.com/luoweihua7/vps-install/master/aria2/aria2.tar.gz -O /tmp/aria2.tar.gz >> /dev/null 2>&1
        curl -# -o /tmp/aria2.tar.gz -L https://raw.githubusercontent.com/luoweihua7/vps-install/master/aria2/aria2.tar.gz
    fi
    echo "Unzip file..."
    # aria2c file download from https://github.com/q3aql/aria2-static-builds
    tar zxf /tmp/aria2.tar.gz -C ${ARIA_CONF_DIR}
    rm -rf /tmp/aria2.tar.gz

    echo "Installing aria2c..."
    mv -f ${ARIA_CONF_DIR}/aria2/aria2c /usr/local/bin
    mv -f ${ARIA_CONF_DIR}/aria2/aria2.sh /etc/init.d/aria2
    chmod 755 /etc/init.d/aria2

    chkconfig --add aria2
    chkconfig aria2 on

    # Configure aria2c complete notify
    setup_aria2c

    if sys_version 6; then
        service aria2 start >> /dev/null 2>&1
    elif sys_version 7; then
        systemctl daemon-reload >> /dev/null 2>&1
        systemctl enable aria2 >> /dev/null 2>&1
        systemctl start aria2 >> /dev/null 2>&1
    fi

    echo ""
    echo "============ Aria2 service installed. ============"

    echo ""
    echo "Setup AriaNg..."
    install_ariang

    echo ""
    echo "Config nginx folder..."

    # Custom domain name
    local download_domain=""
    while true
    do
    stty erase '^H' && read -p $'[\e\033[0;32mINFO\033[0m] Please input AriaNg WebUI domain (eg. www.example.com): ' aria2_domain
    if [ -z ${aria2_domain} ]; then
        echo -e "\033[41;37m ERROR \033[0m Domain required!!!"
        continue
    fi
    download_domain=${aria2_domain}
    break
    done

    mv -f ${ARIA_CONF_DIR}/aria2/nginx_domain.conf /etc/nginx/conf.d/${download_domain}.conf
    sed -i -e "s/_SERVER_NAME_/${download_domain}/g" /etc/nginx/conf.d/${download_domain}.conf
    service nginx restart

    echo ""
    echo "============ All done! ============"
}

function setup_aria2c() {
    echo ""

    # Setup download path
    stty erase '^H' && read -p $'[\e\033[0;32mINFO\033[0m] Please input download path (default: /data/downloads): ' aria2_download_path
    if [ -z ${aria2_download_path} ]; then
        aria2_download_path="/data/downloads"
    fi
    mkdir -p $aria2_download_path
    sed -i -e "s/ARIA_DOWNLOAD_DIR/${aria2_download_path//\//\\/}/g" ${ARIA_CONF_DIR}/aria2/aria2.conf
    sed -i -e "s/ARIA_CONF_DIR/${ARIA_CONF_DIR}/g" ${ARIA_CONF_DIR}/aria2/aria2.conf

    # Setup secret
    stty erase '^H' && read -p $'[\e\033[0;32mINFO\033[0m] Please input secret (default: qwertyuiop): ' aria2_secret
    if [ -z ${aria2_secret} ]; then
        aria2_secret="qwertyuiop"
    fi
    sed -i -e "s/ARIA_SECRET/${aria2_secret}/g" ${ARIA_CONF_DIR}/aria2/aria2.conf

    # IFTTT notification
    stty erase '^H' && read -p $'[\e\033[0;32mINFO\033[0m] Would you want to enable download task completed notification? Y/n: ' ENABLE_NOTIFY
    [ -z "${ENABLE_NOTIFY}" ] && ENABLE_NOTIFY="Y"
    case ${ENABLE_NOTIFY} in
        [yY][eE][sS]|[yY])
            # Enable notify
            echo ""
            echo "Visit https://ifttt.com/maker_webhooks page, and then click \"Document\" button, you will find webhook key."
            while true
            do
            stty erase '^H' && read -p $'[\e\033[0;32mINFO\033[0m] Please input IFTTT webhook key: ' IFTTT_KEY
            if [ -z ${IFTTT_KEY} ]; then
                echo -e "\033[41;37m ERROR \033[0m IFTTT webhook key required!!!"
                echo ""
                continue
            fi
            sed -i -e "s/IFTTT_KEY/${IFTTT_KEY}/g" ${ARIA_CONF_DIR}/aria2/on-download-complete.sh
            sed -i -e "s/IFTTT_KEY/${IFTTT_KEY}/g" ${ARIA_CONF_DIR}/aria2/on-download-error.sh
            break
            done
            ;;
        *)
            # disable notify
            sed -i -e "s/on-download-complete/#on-download-complete/g" ${ARIA_CONF_DIR}/aria2/aria2.conf
            sed -i -e "s/on-download-error/#on-download-error/g" ${ARIA_CONF_DIR}/aria2/aria2.conf
            ;;
    esac
}

function install_ariang() {
    echo ""
    echo "Which type do you want to install? "
    echo "1. release"
    echo "2. master"
    stty erase '^H' && read -p $'[\e\033[0;32mINFO\033[0m] Please enter your choice (1, 2. default [1]): ' INSTALLTYPE
    [ -z "$INSTALLTYPE" ] && INSTALLTYPE="1"

    case "$INSTALLTYPE" in
        1)
            install_ariang_release
            ;;
        2)
            install_ariang_master
            ;;
        *)
            install_ariang
            ;;
    esac
}

function install_ariang_master() {
    yum install -y git -q >> /dev/null 2>&1
    git clone https://github.com/mayswind/AriaNg.git /tmp/AriaNg
    npm i -g gulp bower
    cd /tmp/AriaNg
    npm install
    bower install --allow-root
    gulp clean build
    npm remove -g gulp bower

    mkdir /data/www/aria2 -p
    mv /tmp/AriaNg/dist/* /data/www/aria2 -f
    cd /data
    rm -rf /tmp/AriaNg/
    echo "AriaNg installed."
}

function install_ariang_release() {
    echo ""
    yum install -y unzip -q >> /dev/null 2>&1
    echo "Checking last AriaNg version..."
    aria_ng_path=`wget -qO- https://github.com/mayswind/AriaNg/releases | grep 'releases/download/' | head -n 1 | awk '{print $2}' | sed 's/href=\"//g' | sed 's/\"//g'`
    echo "Last version: https://github.com${aria_ng_path}"
    echo "Downloading AriaNg package file..."
    # wget --no-check-certificate --progress=bar:force https://github.com${aria_ng_path} -O /tmp/AriaNg.zip >> /dev/null 2>&1
    curl -# -o /tmp/AriaNg.zip -L https://github.com${aria_ng_path}
    echo "Unzip file..."
    unzip -u -q /tmp/AriaNg.zip -d /data/www/aria2
    echo "Clean up."
    rm -rf /tmp/AriaNg.zip
    echo "AriaNg installed."
}

function uninstall_aria2c() {
    echo ""
    echo "Removing files..."

    if sys_version 6; then
        service aria2 stop
        rm -rf /etc/init.d/aria2
    elif sys_version 7; then
        systemctl stop aria2.service
        systemctl disable aria2.service
        rm -rf /etc/systemd/system/aria2.service
        systemctl daemon-reload
    fi

    rm -rf /usr/local/bin/aria2c
    rm -rf ${ARIA_CONF_DIR}/aria2
	rm -rf /data/www/aria2
    rm -rf /etc/nginx/conf.d/dl.*.conf

    service nginx restart

    echo ""
    echo "All aria2 files removed."
}

function start() {
    echo ""
    echo "Which do you want to?"
    echo "1. Install aria2c [Include AriaNG Web UI]"
    echo "2. Uninstall aria2c"
    echo "3. Install AriaNg Web UI"
    stty erase '^H' && read -p $'[\e\033[0;32mINFO\033[0m] Please input the number and press enter.  (Press other key to exit): ' num

    case "$num" in
    [1] ) (install_aria2c);;
    [2] ) (uninstall_aria2c);;
    [3] ) (install_ariang);;
    *) echo "Bye~~~";;
    esac
}

start