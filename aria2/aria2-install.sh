#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

function get_os_version(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else    
        grep -oE  "[0-9.]+" /etc/issue
    fi    
}

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

function install_aria2c() {
    mkdir /home/conf/aria2 -p
    mkdir /home/downloads -p
    mkdir /home/www -p

    wget --no-check-certificate https://github.com/luoweihua7/vps-install/raw/master/aria2/aria2.tar.gz -O /tmp/aria2.tar.gz
    echo "Unzip file..."
    tar zxf /tmp/aria2.tar.gz -C /home/conf/
    rm -rf /tmp/aria2.tar.gz

    echo "Moving aria2c to correct directory"
    mv /home/conf/aria2/aria2c /usr/local/bin
    mv /home/conf/aria2/aria2c.sh /etc/init.d/aria2c
    chmod 755 /etc/init.d/aria2c

    chkconfig --add aria2c
    chkconfig aria2c on

    if sys_version 6; then
        service aria2c start
    elif sys_version 7; then
        systemctl daemon-reload
        systemctl enable aria2c
        systemctl start aria2c
    fi

    echo ""
    echo "Aria2 installed."

    echo ""
    echo "Setup AriaNg..."

    git clone https://github.com/mayswind/AriaNg.git /tmp/AriaNg
    npm i -g gulp bower
    cd /tmp/AriaNg
    npm install
    bower install --allow-root
    gulp clean build
    npm remove -g gulp bower

    mkdir /home/www/aria2 -p
    mv /tmp/AriaNg/dist/* /home/www/aria2 -f
    cd /home
    rm -rf /tmp/AriaNg/

    echo ""
    echo "Config nginx folder..."
    mv /home/conf/aria2/nginx.*.conf /etc/nginx/default.d/
    service nginx restart

    echo "All done!"
}

function uninstall_aria2c() {
    echo "Removing files..."

    if sys_version 6; then
        service aria2c stop
        rm -rf /etc/init.d/aria2c
    elif sys_version 7; then
        systemctl stop aria2c.service
        systemctl disable aria2c.service
        rm -rf /etc/systemd/system/aria2c.service
        systemctl daemon-reload
    fi

    rm -rf /usr/local/bin/aria2c
    rm -rf /home/conf/aria2
	rm -rf /home/www/aria2
    rm -rf /etc/nginx/default.d/nginx.*.conf

    echo ""
    echo "All aria2 files removed."
}

function start() {
    echo ""
    echo "Which do you want to? Input the number and press enter. (Press other key to exit)"
    echo "1. Install"
    echo "2. Uninstall"
    read num

    case "$num" in
    [1] ) (install_aria2c);;
    [2] ) (uninstall_aria2c);;
    *) echo "";;
    esac
}

start