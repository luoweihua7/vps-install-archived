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

function install_aria2c() {
    mkdir /home/conf/aria2 -p
    mkdir /home/downloads -p
    mkdir /home/www -p

    echo "Downloading file..."
    wget --no-check-certificate --progress=bar:force https://github.com/luoweihua7/vps-install/raw/master/aria2/aria2.tar.gz -O /tmp/aria2.tar.gz 2>&1 | progressfilter
    echo "Unzip file..."
    # aria2c file download from https://github.com/q3aql/aria2-static-builds
    tar zxf /tmp/aria2.tar.gz -C /home/conf/
    rm -rf /tmp/aria2.tar.gz

    echo "Moving aria2c to correct directory"
    mv /home/conf/aria2/aria2c /usr/local/bin
    mv /home/conf/aria2/aria2.sh /etc/init.d/aria2
    chmod 755 /etc/init.d/aria2

    chkconfig --add aria2
    chkconfig aria2 on

    if sys_version 6; then
        service aria2 start
    elif sys_version 7; then
        systemctl daemon-reload
        systemctl enable aria2
        systemctl start aria2
    fi

    echo ""
    echo "Aria2 installed."

    echo ""
    echo "Setup AriaNg..."
    install_ariang

    echo ""
    echo "Config nginx folder..."
    mv /home/conf/aria2/nginx.*.conf /etc/nginx/default.d/
    service nginx restart

    echo ""
    echo "All done!"
}

function install_ariang() {
    echo ""
    echo "Which type do you want to install? "
    echo "1. release"
    echo "2. master"
    read -p "Please enter your choice (1, 2. default [1]): " INSTALLTYPE
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
    yum install -y git -q
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
    echo "AriaNg installed."
}

function install_ariang_release() {
    yum install -y unzip -q
    echo "Checking last version..."
    aria_ng_path=`wget -qO- https://github.com/mayswind/AriaNg/releases | grep 'releases/download/' | head -n 1 | awk '{print $2}' | sed 's/href=\"//g' | sed 's/\"//g'`
    echo "Last version: https://github.com${aria_ng_path}"
    echo "Downloading file..."
    wget --no-check-certificate --progress=bar:force https://github.com${aria_ng_path} -O /tmp/AriaNg.zip 2>&1 | progressfilter
    echo "Unzip file..."
    unzip -u -q /tmp/AriaNg.zip -d /home/www/aria2
    echo "Clean up."
    rm -rf /tmp/AriaNg.zip
    echo "AriaNg installed."
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
    echo "Which do you want to?"
    echo "1. Install aria2c [Include Web UI]"
    echo "2. Uninstall aria2c"
    echo "3. Install AriaNg Web UI"
    read -p "Please input the number and press enter.  (Press other key to exit): " num

    case "$num" in
    [1] ) (install_aria2c);;
    [2] ) (uninstall_aria2c);;
    [3] ) (install_ariang);;
    *) echo "Bye~~~";;
    esac
}

start