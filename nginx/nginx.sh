#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Is need github private access token, 0:no, 1:yes
is_need_token="1"
private_token=""

# Replace exists file
is_replace="1"

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

    if [ -s ${filename} ] && [ "${is_replace}" == "0" ]; then
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
            echo -e "\033[41;37m ERROR \033[0m Failed to download ${filename}, please download it to ${1} directory manually and try again."
            echo -e "Download link: ${2}"
            echo ""
            exit 1
        fi
    fi
}

setup() {
    echo -e "Downloading custom pages..."
    pages=(
        index.html
        40x.html
        50x.html
    )
    for ((i=1;i<=${#pages[@]};i++ )); do
        hint="${pages[$i-1]}"
        rm -rf /usr/share/nginx/html/${hint}
        download "/usr/share/nginx/html/${hint}" "https://raw.githubusercontent.com/luoweihua7/vps-install/master/nginx/${hint}" "${is_need_token}"
    done

    sed -i -e "s/#error_page/error_page/g" /etc/nginx/conf.d/default.conf
    sed -i -e "s/404.html/40x.html/g" /etc/nginx/conf.d/default.conf
    nginx -s reload

    echo "Done!"
    echo ""
}

setup