#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Color
red='\033[41;37m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Message
INFO="${green}[INFO]${plain}"
WARN="${yellow}[WARN]${plain}"
ERROR="${red}[ERROR]${plain}"
SUCCESS="${green}[SUCCESS]${plain}"

# Path
v2ray_conf_dir="/etc/v2ray"
nginx_conf_dir="/etc/nginx/conf.d"
v2ray_conf="${v2ray_conf_dir}/config.json"
v2ray_ssl_dir="/home/conf/nginx"

V2RAY_DOMAIN=""
V2RAY_PORT=""
V2RAY_UUID=`cat /proc/sys/kernel/random/uuid`
V2RAY_PATH=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`

v2ray_config() {
  stty erase '^H' && stty erase ^? && read -p "Please input domain(eg: www.example.com):" v2domain
  local_ip=`curl -4 ip.sb` &>/dev/null

  local default_port=`shuf -i 10000-39999 -n 1`
  while true
  do
  echo ""
  stty erase '^H' && stty erase ^? && read -p "Please input v2ray server port (default: ${default_port}): " v2port
  [ -z "$v2port" ] && v2port=$default_port
  expr $v2port + 0 &>/dev/null
  if [ $? -eq 0 ]; then
    if [ $v2port -ge 1 ] && [ $v2port -le 65535 ]; then
      if [[ 0 -eq `lsof -i:"$v2port" | wc -l` ]];then
        break
      else
        echo -e "${ERROR} Server port $v2port already in use. please change another one."
        lsof -i:"$v2port"
        echo ""
      fi
    else
      echo -e "${ERROR} Input error! Please input correct port numbers (1-65535)."
    fi
  else
    echo -e "${ERROR} Input error! Please input correct port numbers (1-65535)."
  fi
  done

  V2RAY_DOMAIN="${v2domain}"
  V2RAY_PORT="${v2port}"
}

preinstall() {
  echo -e "${INFO} Installing dependency packages..."
  # qrencode 是生成二维码用的
  yum install wget lsof crontabs bc unzip ntpdate socat nc qrencode -y

  systemctl stop ntp &>/dev/null
  ntpdate time.nist.gov
}

v2ray_core_install(){
  wget --no-check-certificate https://install.direct/go.sh -O v2ray-core.sh
  bash v2ray-core.sh --force
  rm -rf v2ray-core.sh
}

ssl_install() {
  echo -e "${INFO} Installing Let's Encrypt SSL certificate..."
  curl  https://get.acme.sh | sh

  stty erase '^H' && stty erase ^? && read -p "Please input Aliyun AccessKey ID:" access_key
  stty erase '^H' && stty erase ^? && read -p "Please input Aliyun Access Key Secret:" access_secret

  export Ali_Key="${access_key}"
  export Ali_Secret="${access_secret}"

  ~/.acme.sh/acme.sh --issue --dns dns_ali -d ${V2RAY_DOMAIN}

  # Check certificate exist
  if [ ! -f ~/.acme.sh/${V2RAY_DOMAIN}/${V2RAY_DOMAIN}.cer ]; then
    echo -e "${ERROR} Generate certificate fail."
    exit 3
  else
    mkdir -p ${v2ray_ssl_dir}
    local nginx_conf="${nginx_conf_dir}/${V2RAY_DOMAIN}.conf"
    wget --no-check-certificate --no-cache -cq -t3 "https://raw.githubusercontent.com/luoweihua7/vps-install/master/v2ray/config/nginx_template.conf" -O ${nginx_conf}

    sed -i -e "s/_DOMAIN_/${V2RAY_DOMAIN}/g" ${nginx_conf}
    sed -i -e "s/_PORT_/${V2RAY_PORT}/g" ${nginx_conf}
    sed -i -e "s/_PATH_/${V2RAY_PATH}/g" ${nginx_conf}

    # Install certificate
    ~/.acme.sh/acme.sh --installcert -d ${V2RAY_DOMAIN} --fullchainpath ${v2ray_ssl_dir}/${V2RAY_DOMAIN}.crt --keypath ${v2ray_ssl_dir}/${V2RAY_DOMAIN}.key --reloadcmd "service nginx force-reload"
  fi
}

v2ray_config_install() {
  wget --no-check-certificate --no-cache -cq -t3 "https://raw.githubusercontent.com/luoweihua7/vps-install/master/v2ray/config/server.json" -O ${v2ray_conf}

  sed -i -e "s/V2RAY_UUID/${V2RAY_UUID}/g" ${nginx_conf}
  sed -i -e "s/V2RAY_PORT/${V2RAY_PORT}/g" ${nginx_conf}
  sed -i -e "s/V2RAY_PATH/${V2RAY_PATH}/g" ${nginx_conf}
}

firewall_config() {
  add_firewall 80
  add_firewall 443
  add_firewall V2RAY_PORT
}

startup_v2ray() {
  systemctl enable nginx
  systemctl restart nginx

  systemctl enable v2ray
  systemctl restart v2ray
}

show_qrcode() {
  # yum install qrencode 
  echo -e "Show QRCode"
}

show_information() {
  echo ""
  echo ""
  echo -e "${green} V2ray+ws+tls install success. ${plain}"
  echo -e "Domain\t${green} $V2RAY_DOMAIN ${plain}"
  echo -e "Port\t${green} $V2RAY_PORT ${plain}"
  echo -e "UUID\t${green} $V2RAY_UUID ${plain}"
  echo -e "Path\t${green} $V2RAY_PATH ${plain}"
  echo -e "alterId\t${green} 64 ${plain}"
  echo -e "Network\t${green} ws ${plain}"
  echo ""
}

v2ray_install() {
  echo -e "${INFO} Starting install v2ray..."
  v2ray_config
  preinstall
  v2ray_core_install
  ssl_install
  v2ray_config_install
  firewall_config
  startup_v2ray
  show_information
}

v2ray_uninstall() {
  systemctl stop v2ray
  systemctl disable v2ray
  rm -rf /etc/systemd/system/v2ray.service
  systemctl daemon-reload

  rm -rf /etc/v2ray
  rm -rf /usr/bin/v2ray
  rm -rf /var/log/v2ray
}

add_firewall() {
    PORT=$1

    echo -e "${INFO} Configuring firewall..."

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

    echo -e "${INFO} Firewall setup completed..."
}

main() {
  echo ""
  echo -e "${INFO} Which one do you want to do?"
  echo "1. Install V2Ray"
  echo "2. Uninstall V2Ray"
  stty erase '^H' && stty erase ^? && read -p "Input the number and press enter. (Press any other key to exit) " num

  case "$num" in
    [1] ) (v2ray_install);;
    [2] ) (v2ray_uninstall);;
    *) echo "Bye~~~";;
  esac
}

main