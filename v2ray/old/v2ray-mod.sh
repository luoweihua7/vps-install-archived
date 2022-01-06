#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Font Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
purple='\033[0;35m'
cyan='\033[0;36m'
plain='\033[0m'

# Background Color
bg_red='\033[41;37m'
bg_green='\033[42;37m'
bg_yellow='\033[43;37m'
bg_blue='\033[44;37m'
bg_purple='\033[45;37m'
bg_cyan='\033[46;37m'

# Message
INFO="${green}[INFO]${plain}"
WARN="${yellow}[WARN]${plain}"
ERROR="${bg_yellow}[ERROR]${plain}"
SUCCESS="${green}[SUCCESS]${plain}"
READ_INFO=$'\e[31m[INFO]\e[0m'

# Path
git_url="https://raw.githubusercontent.com/luoweihua7/vps-install/master"
v2ray_conf_dir="/etc/v2ray"
nginx_conf_dir="/etc/nginx/conf.d"
v2ray_conf="${v2ray_conf_dir}/config.json"
v2ray_ssl_dir="/etc/nginx/ssl"

nginx_conf=""
v2ray_conf_backup=""

V2RAY_DOMAIN=""
V2RAY_PORT=""
V2RAY_UUID=`cat /proc/sys/kernel/random/uuid`
V2RAY_PATH=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`

fun_randstr(){
    index=0
    strRandomPass=""
    for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {1..16}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
    echo $strRandomPass
}

v2ray_config() {
  # prepare package
  local lsof_installed=`rpm -qa | grep firewalld | wc -l`
  if [ ${lsof_installed} -ne 0 ]; then
    yum install lsof -y &>/dev/null
  fi

  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input subdomain (eg: sub.example.com):" v2domain

  local v2port=4443
  while true
  do
    local rand_port=`shuf -i 10000-59999 -n 1`
    if [[ 0 -eq `lsof -i:"${rand_port}" | wc -l` ]];then
      v2port="${rand_port}"
      expr ${v2port} + 0 &>/dev/null
      break
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
  bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
}

ssl_install() {
  # Download and replace params
  mkdir -p ${v2ray_ssl_dir}
  nginx_conf="${nginx_conf_dir}/${V2RAY_DOMAIN}.conf"
  echo "
server {
    listen                443 ssl;
    ssl_certificate       V2RAY_SSL_DIR/V2RAY_DOMAIN.crt;
    ssl_certificate_key   V2RAY_SSL_DIR/V2RAY_DOMAIN.key;
    ssl_protocols         TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers           HIGH:!aNULL:!MD5;
    server_name           V2RAY_DOMAIN;
    index                 index.html index.htm;
    root                  /usr/share/nginx/html;

    location /V2RAY_PATH {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:V2RAY_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";

        # Show realip in v2ray access.log
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
server {
    listen 80;
    server_name V2RAY_DOMAIN;
    return 301 https://V2RAY_DOMAIN\\\$request_uri;
}
" > ${nginx_conf}
  sed -i -e "s/V2RAY_DOMAIN/${V2RAY_DOMAIN}/g" ${nginx_conf}
  sed -i -e "s/V2RAY_PORT/${V2RAY_PORT}/g" ${nginx_conf}
  sed -i -e "s/V2RAY_PATH/${V2RAY_PATH}/g" ${nginx_conf}


  echo ""
  echo -e "Which one do you want to do?"
  echo "1. Use exist certificate"
  echo "2. Register new certificate"
  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Input the number and press enter. (Press any other key to exit) " num

  case "${num}" in
    [1] )
      # Use exist certificate
      echo -e "For example: your certificate in ${purple}/etc/nginx/ssl/${plain}${cyan}domain.com${plain}.crt"
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input certificate directory (eg. /etc/nginx/ssl/): " ssl_dir
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input certificate name (eg. domain.com): " ssl_name
      #
    ;;
    [2] )
      # Register new certificate
      echo -e "Installing Let's Encrypt SSL certificate..."
      curl  https://get.acme.sh | sh

      # Input Aliyun AccessKey
      echo ""
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input Aliyun AccessKey ID: " access_key
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input Aliyun Access Key Secret: " access_secret
      echo ""

      export Ali_Key="${access_key}"
      export Ali_Secret="${access_secret}"

      RANDOM_RECORD=`fun_randstr`
      ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
      ~/.acme.sh/acme.sh --issue --dns dns_ali -d ${V2RAY_DOMAIN} -d *.${V2RAY_DOMAIN} -d *.${RANDOM_RECORD}.${V2RAY_DOMAIN} --yes-I-know-dns-manual-mode-enough-go-ahead-please --force

      # Check certificate exist
      if [ ! -f ~/.acme.sh/${V2RAY_DOMAIN}/${V2RAY_DOMAIN}.cer ]; then
        echo -e "${ERROR} Generate certificate fail."
        exit 3
      else
        sed -i -e "s/V2RAY_DOMAIN/${V2RAY_DOMAIN}/g" ${nginx_conf}
        sed -i -e "s/V2RAY_PORT/${V2RAY_PORT}/g" ${nginx_conf}
        sed -i -e "s/V2RAY_PATH/${V2RAY_PATH}/g" ${nginx_conf}

        # Install certificate
        ~/.acme.sh/acme.sh --installcert -d ${V2RAY_DOMAIN} --fullchainpath ${v2ray_ssl_dir}/${V2RAY_DOMAIN}.crt --keypath ${v2ray_ssl_dir}/${V2RAY_DOMAIN}.key --reloadcmd "service nginx force-reload"
      fi
    ;;
    *) echo "Bye~~~";;
  esac

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

  echo "
{
  \"log\": {
    \"access\": \"/var/log/v2ray/access.log\",
    \"loglevel\": \"warning\",
    \"error\": \"/var/log/v2ray/error.log\"
  },
  \"inbounds\": [
    {
      \"port\": V2RAY_PORT,
      \"listen\": \"127.0.0.1\",
      \"tag\": \"vmess-in\",
      \"protocol\": \"vmess\",
      \"settings\": {
        \"clients\": [
          {
            \"id\": \"V2RAY_UUID\",
            \"alterId\": 64
          }
        ]
      },
      \"streamSettings\": {
        \"network\": \"ws\",
        \"security\": \"none\",
        \"wsSettings\": {
          \"path\": \"/V2RAY_PATH\"
        }
      }
    }
  ],
  \"outbounds\": [
    {
      \"protocol\": \"freedom\",
      \"settings\": {},
      \"tag\": \"direct\"
    },
    {
      \"protocol\": \"blackhole\",
      \"settings\": {},
      \"tag\": \"blocked\"
    }
  ],
  \"routing\": {
    \"domainStrategy\": \"AsIs\",
    \"rules\": [
      {
        \"outboundTag\": \"blocked\",
        \"type\": \"field\",
        \"ip\": [
          \"geoip:private\"
        ]
      }
    ]
  }
}
" > ${v2ray_conf}

  sed -i -e "s/V2RAY_UUID/${V2RAY_UUID}/g" ${v2ray_conf}
  sed -i -e "s/V2RAY_PORT/${V2RAY_PORT}/g" ${v2ray_conf}
  sed -i -e "s/V2RAY_PATH/${V2RAY_PATH}/g" ${v2ray_conf}
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
  if [ ! -z ${v2ray_conf_backup} ]; then
    echo -e "${INFO} Old V2Ray config file backup in ${green} ${v2ray_conf_backup} ${plain}"
    echo ""
  fi

  echo ""
  echo -e "${bg_blue}   V2Ray (Websocket + TLS + Nginx)   ${plain}"
  echo -e "Domain\t${green} ${V2RAY_DOMAIN} ${plain}"
  echo -e "Port\t${green} ${V2RAY_PORT} ${plain}"
  echo -e "UUID\t${green} ${V2RAY_UUID} ${plain}"
  echo -e "Path\t${green} /${V2RAY_PATH} ${plain}"
  echo -e "alterId\t${green} 64 ${plain}"
  echo -e "Network\t${green} ws ${plain}"
  echo ""

  # ClashX config
  echo -e "${bg_blue}   ClashX   ${plain}"
  echo -e "${green}- { name: "V2Ray", type: vmess, server: ${V2RAY_DOMAIN}, port: 443, uuid: ${V2RAY_UUID}, alterId: 64, cipher: auto, network: ws, ws-path: /${V2RAY_PATH}, tls: true }${plain}"
  echo ""

  # Shadowrocket config
  echo -e "${bg_blue}   Shadowrocket   ${plain}"
  echo -e "${green}vmess://`echo -n 'none:'${V2RAY_UUID}'@'${LOCAL_IP}':443' | base64 -w 0`?remarks=VMESS&path=/${V2RAY_PATH}&obfs=websocket&tls=1${plain}"
  echo ""

  # Quantumult config
  echo -e "${bg_blue}   Quantmult   ${plain}"
  echo -e "${green}vmess://`echo -n 'V2Ray = vmess, '${LOCAL_IP}', 443, none, "'${V2RAY_UUID}'", over-tls=true, tls-host='${V2RAY_DOMAIN}', certificate=0, obfs=ws, obfs-path="/'${V2RAY_PATH}'", obfs-header="Host: '${V2RAY_DOMAIN}'"' | base64 -w 0`${plain}"
  echo ""
  echo -e "If firewall enabled, please configure firewall rules manually"
  echo -e "Please add the configuration manually"
  echo ""
}

v2ray_install() {
  v2ray_config
  preinstall
  v2ray_core_install
  ssl_install
  v2ray_config_install
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

  # Remove nginx config
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Would you want to remove nginx domain config (Only conf file)? Y/n: " REMOVE_CONF
  [ -z "${REMOVE_CONF}" ] && REMOVE_CONF="Y"
  case ${REMOVE_CONF} in
    [yY][eE][sS]|[yY])
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input websocket subdomain (eg: sub.example.com):" REMOVE_DOMAIN
      rm -rf ${nginx_conf_dir}/${REMOVE_DOMAIN}.conf

      # Remove SSl certificate and acms.sh files
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Would you want to remove SSL certificate (include acme.sh)? Y/n: " REMOVE_SSL
      [ -z "${REMOVE_SSL}" ] && REMOVE_SSL="Y"
      case ${REMOVE_CONF} in
        [yY][eE][sS]|[yY])
          rm -rf ${v2ray_ssl_dir}/${REMOVE_DOMAIN}.crt
          rm -rf ${v2ray_ssl_dir}/${REMOVE_DOMAIN}.key

          ~/.acme.sh/acme.sh --uninstall
          # rm -rf ~/.acme.sh
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