#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

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

# Path
git_url="https://raw.githubusercontent.com/luoweihua7/vps-install/master"
v2ray_conf_dir="/etc/v2ray"
nginx_conf_dir="/etc/nginx/conf.d"
v2ray_conf="${v2ray_conf_dir}/config.json"
v2ray_ssl_dir="/home/conf/nginx"

nginx_conf=""
v2ray_conf_backup=""

V2RAY_DOMAIN=""
V2RAY_PORT=""
V2RAY_UUID=`cat /proc/sys/kernel/random/uuid`
V2RAY_PATH=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`

add_firewall() {
    PORT=$1

    local firewalld_installed=`rpm -qa | grep firewalld | wc -l`
    if [ ${firewalld_installed} -ne 0 ]; then
      systemctl status firewalld > /dev/null 2>&1
      if [ $? -eq 0 ];then
        firewall-cmd --permanent --zone=public --add-port=${PORT}/tcp -q
        firewall-cmd --permanent --zone=public --add-port=${PORT}/udp -q
        firewall-cmd --reload -q
        echo -e "Firewall port ${PORT} add success."
      else
        echo -e "${WARN} Firewalld looks like not running, try to start..."
        systemctl start firewalld -q
        if [ $? -eq 0 ];then
          firewall-cmd --permanent --zone=public --add-port=${PORT}/tcp -q
          firewall-cmd --permanent --zone=public --add-port=${PORT}/udp -q
          firewall-cmd --reload -q
        else
          echo -e "${ERROR} Try to start firewalld failed. please manually set it if necessary."
        fi
      fi
    else
      echo -e "${ERROR} Firewalld looks like not installed, please manually set it if necessary."
    fi
}

remove_firewall() {
  PORT=$1

  local firewalld_installed=`rpm -qa | grep firewalld | wc -l`
  if [ ${firewalld_installed} -ne 0 ]; then
    firewall-cmd --permanent --zone=public --remove-port=${PORT}/tcp -q
    firewall-cmd --permanent --zone=public --remove-port=${PORT}/udp -q
    firewall-cmd --reload -q
    echo -e "Firewall port ${PORT} removed."
  else
    echo -e "${ERROR} Firewalld looks like not installed, please manually set it if necessary."
  fi
}

v2ray_config() {
  # prepare package
  local lsof_installed=`rpm -qa | grep firewalld | wc -l`
  if [ ${lsof_installed} -ne 0 ]; then
    yum install lsof -y &>/dev/null
  fi

  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input domain(eg: www.example.com):" v2domain

  local default_port=`shuf -i 10000-39999 -n 1`
  while true
  do
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input v2ray server port (default: ${default_port}): " v2port
  [ -z "${v2port}" ] && v2port=${default_port}
  expr ${v2port} + 0 &>/dev/null
  if [ $? -eq 0 ]; then
    if [ ${v2port} -ge 1 ] && [ ${v2port} -le 65535 ]; then
      if [[ 0 -eq `lsof -i:"${v2port}" | wc -l` ]];then
        break
      else
        echo -e "${ERROR} Server port ${v2port} already in use. please change another one."
        lsof -i:"${v2port}"
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
  echo -e "Installing dependency packages..."
  yum install wget crontabs bc unzip ntpdate socat nc -y

  systemctl stop ntp &>/dev/null
  ntpdate time.nist.gov
}

v2ray_core_install() {
  # Force install
  wget --no-check-certificate https://install.direct/go.sh -O v2ray-core.sh
  bash v2ray-core.sh --force
  rm -rf v2ray-core.sh
}

ssl_install() {
  echo -e "Installing Let's Encrypt SSL certificate..."
  curl  https://get.acme.sh | sh

  # Input Aliyun AccessKey
  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input Aliyun AccessKey ID:" access_key
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input Aliyun Access Key Secret:" access_secret
  echo ""

  export Ali_Key="${access_key}"
  export Ali_Secret="${access_secret}"

  ~/.acme.sh/acme.sh --issue --dns dns_ali -d ${V2RAY_DOMAIN}

  # Check certificate exist
  if [ ! -f ~/.acme.sh/${V2RAY_DOMAIN}/${V2RAY_DOMAIN}.cer ]; then
    echo -e "${ERROR} Generate certificate fail."
    exit 3
  else
    mkdir -p ${v2ray_ssl_dir}
    nginx_conf="${nginx_conf_dir}/${V2RAY_DOMAIN}.conf"
    wget --no-check-certificate --no-cache -cq -t3 "${git_url}/v2ray/config/nginx_template.conf" -O ${nginx_conf}

    sed -i -e "s/V2RAY_DOMAIN/${V2RAY_DOMAIN}/g" ${nginx_conf}
    sed -i -e "s/V2RAY_PORT/${V2RAY_PORT}/g" ${nginx_conf}
    sed -i -e "s/V2RAY_PATH/${V2RAY_PATH}/g" ${nginx_conf}

    # Install certificate
    ~/.acme.sh/acme.sh --installcert -d ${V2RAY_DOMAIN} --fullchainpath ${v2ray_ssl_dir}/${V2RAY_DOMAIN}.crt --keypath ${v2ray_ssl_dir}/${V2RAY_DOMAIN}.key --reloadcmd "service nginx force-reload"
  fi
}

v2ray_config_install() {
  # Backup old config file
  local config_exists=`grep "path" ${v2ray_conf} | wc -l`
  if [ ${config_exists} -ne 0 ]; then
    local path_conf=`grep "path" ${v2ray_conf} | awk {'print $2'} | sed 's/\"\///g' | sed 's/\"//g'`
    v2ray_conf_backup="${v2ray_conf_dir}/conf.${path_conf}.json"
    mv -f ${v2ray_conf} ${v2ray_conf_backup}
  else
    rm -rf ${v2ray_conf}
  fi

  wget --no-check-certificate --no-cache -cq -t3 "${git_url}/v2ray/config/config.json" -O ${v2ray_conf}

  sed -i -e "s/V2RAY_UUID/${V2RAY_UUID}/g" ${v2ray_conf}
  sed -i -e "s/V2RAY_PORT/${V2RAY_PORT}/g" ${v2ray_conf}
  sed -i -e "s/V2RAY_PATH/${V2RAY_PATH}/g" ${v2ray_conf}
}

firewall_config() {
  add_firewall 80
  add_firewall 443
  add_firewall ${V2RAY_PORT}
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
  local LOCAL_IP=`curl -4 -s ip.sb`

  # Show old config backup info
  if [ -z ${v2ray_conf_backup} ]; then
    echo -e "${INFO} Old V2Ray config file backup in ${green} ${v2ray_conf_backup} ${plain}"
    echo ""
  fi

  echo ""
  echo -e "${blue_bg}   V2Ray (Websocket + TLS + Nginx)   ${plain}"
  echo -e "Domain\t${green} ${V2RAY_DOMAIN} ${plain}"
  echo -e "Port\t${green} ${V2RAY_PORT} ${plain}"
  echo -e "UUID\t${green} ${V2RAY_UUID} ${plain}"
  echo -e "Path\t${green} /${V2RAY_PATH} ${plain}"
  echo -e "alterId\t${green} 64 ${plain}"
  echo -e "Network\t${green} ws ${plain}"
  echo ""

  # ClashX config
  echo -e "${blue_bg}   ClashX   ${plain}"
  echo -e "${green}- { name: "V2Ray", type: vmess, server: ${V2RAY_DOMAIN}, port: 443, uuid: ${V2RAY_UUID}, alterId: 64, cipher: auto, network: ws, ws-path: /${V2RAY_PATH}, tls: true }${plain}"
  echo -e "Please add the configuration manually"
  echo ""

  # Shadowrocket config
  echo -e "${blue_bg}   Shadowrocket   ${plain}"
  echo -e "${green}vmess://`echo -n 'none:'${V2RAY_UUID}'@'${LOCAL_IP}':443' | base64 -w 0`?remarks=VMESS&path=/${V2RAY_PATH}&obfs=websocket&tls=1${plain}"
  echo ""

  # Quantumult config
  echo -e "${blue_bg}   Quantmult   ${plain}"
  echo -e "${green}vmess://`echo -n 'V2Ray = vmess, '${LOCAL_IP}', 443, none, "'${V2RAY_UUID}'", over-tls=true, tls-host='${V2RAY_DOMAIN}', certificate=0, obfs=ws, obfs-path="/'${V2RAY_PATH}'", obfs-header="Host: '${V2RAY_DOMAIN}'"' | base64 -w 0`${plain}"
  echo ""
}

v2ray_install() {
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

  echo -e "${green} V2Ray Core uninstalled.${plain}"

  while true
  do
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input v2ray server port: " REMOVE_PORT
  expr ${REMOVE_PORT} + 0 &>/dev/null
  if [ $? -eq 0 ]; then
    if [ ${REMOVE_PORT} -ge 1 ] && [ ${REMOVE_PORT} -le 65535 ]; then
      remove_firewall ${REMOVE_PORT}
      break
    else
      echo -e "${ERROR} Input error! Please input correct port numbers (1-65535)."
    fi
  else
    echo -e "${ERROR} Input error! Please input correct port numbers (1-65535)."
  fi
  done

  # Remove nginx config
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Would you want to remove nginx domain config (Just config file)? Y/n: " REMOVE_CONF
  [ -z "${REMOVE_CONF}" ] && REMOVE_CONF="Y"
  case ${REMOVE_CONF} in
    [yY][eE][sS]|[yY])
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input domain or subdomain (eg: www.example.com):" REMOVE_DOMAIN
      rm -rf ${nginx_conf_dir}/${REMOVE_DOMAIN}.conf

      # Remove SSl certificate and acms.sh files
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Would you want to remove SSL certificate (include acme.sh)? Y/n: " REMOVE_SSL
      [ -z "${REMOVE_SSL}" ] && REMOVE_SSL="Y"
      case ${REMOVE_CONF} in
        [yY][eE][sS]|[yY])
          rm -rf ${v2ray_ssl_dir}/${REMOVE_DOMAIN}.crt
          rm -rf ${v2ray_ssl_dir}/${REMOVE_DOMAIN}.key

          ~/.acme.sh/acme.sh --uninstall
          rm -rf ~/.acme.sh
          ;;
        *)
          ;;
      esac

      service nginx restart
      ;;
    *)
      ;;
  esac

  echo -e "${INFO} V2Ray uninstalled."
  echo ""
}

main() {
  echo ""
  echo -e "Which one do you want to do?"
  echo "1. Install V2Ray (Websocket + TLS + Nginx)"
  echo "2. Uninstall V2Ray"
  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Input the number and press enter. (Press any other key to exit) " num

  case "${num}" in
    [1] ) (v2ray_install);;
    [2] ) (v2ray_uninstall);;
    *) echo "Bye~~~";;
  esac
}

main