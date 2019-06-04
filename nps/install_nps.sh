#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cur_dir=`pwd`

# Is need github private access token, 0:no, 1:yes
is_need_token="0"
private_token=""

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
            echo -e "\033[41;37m ERROR \033[0m Failed to download ${filename}, please download it to ${1} directory manually and try again."
            echo -e "Download link: ${2}"
            echo ""
            exit 1
        fi
    fi
}

install_nps() {
    # Download file
    echo -e "[${green}INFO${plain}] Starting install latest NPS..."
    ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/cnlh/nps/releases/latest | grep 'tag_name' | cut -d\" -f4)
    [ -z ${ver} ] && echo -e "\033[41;37m ERROR \033[0m Get NPS latest version failed" && exit 1
    local nps_file="linux_amd64_server.tar.gz"
    download_link="https://github.com/cnlh/nps/releases/download/${ver}/${nps_file}"
    download "${nps_file}" "${download_link}"
    echo "Unzip file..."
    tar -zxf ${nps_file} -C /usr/local/
    echo "Unzip done."

    # Config startup script
    echo ""
    echo -e "[${green}INFO${plain}] Downloading NPS startup script."
    download "/etc/init.d/nps" "https://raw.githubusercontent.com/luoweihua7/vps-install/master/nps/nps.d.sh" "${is_need_token}"
    chmod 755 /etc/init.d/nps
    echo -e "[${green}INFO${plain}] Configuring startup script."
    chkconfig --add nps
    chkconfig nps on
    echo -e "[${green}INFO${plain}] Startup script setup completed."

    service nps start
}