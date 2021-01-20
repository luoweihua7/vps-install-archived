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

NGINX_CERT_DIR="/etc/nginx/certificates"
DNS_SERVICE=""

fun_randstr(){
    index=0
    strRandomPass=""
    for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {1..16}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
    echo $strRandomPass
}

acme_install() {
  echo -e "${INFO} Installing acme.sh service..."
  curl  https://get.acme.sh | sh
  echo -e "${SUCCESS} acme.sh service install success."

  main
}

acme_configure_check() {
  if [ "${DNS_SERVICE}" == "dns_ali" ]; then
    # Aliyun
    ali_conf=`grep "SAVED_Ali_Key" ~/.acme.sh/account.conf | wc -l`
    if [ ${ali_conf} -ne 0 ]; then
      echo -e "${INFO} Aliyun already configured."
    else
      echo -e "${INFO} Please configure Aliyun secret first."
      # Aliyun AccessKey
      echo ""
      echo "Aliyun AccessKey page: https://ram.console.aliyun.com/manage/ak"
      echo ""
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input Aliyun AccessKey ID: " ali_key
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input Aliyun AccessKey Secret: " ali_secret
      echo ""

      export Ali_Key="${ali_key}"
      export Ali_Secret="${ali_secret}"
    fi
  elif [ "${DNS_SERVICE}" == "dns_dp" ]; then
    # DNSPod
    dp_conf=`grep "SAVED_DP_Id" ~/.acme.sh/account.conf | wc -l`
    if [ ${dp_conf} -ne 0 ]; then
      echo -e "${INFO} DNSPod already configured."
    else
      echo -e "${INFO} Please configure DNSPod secret first."
      # DNSPod API
      echo ""
      echo "DNSPod API Token page: https://console.dnspod.cn/account/token"
      echo ""
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input DNSPod API ID: " dp_id
      stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input DNSPod API Token: " dp_key
      echo ""

      export DP_Id="${dp_id}"
      export DP_Key="${dp_key}"
    fi
  else
      echo -e "${ERROR} Unsupported service, please try again."
      exit 1
  fi
}

choose_service() {
  # Choose dns service
  echo ""
  echo -e "Which one dns do you want to configure?"
  echo "1. Aliyun"
  echo "2. DNSPod"
  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Input the number and press enter. (Press any other key to exit) " num

  case "${num}" in
    [1] )
      DNS_SERVICE="dns_ali"
    ;;
    [2] )
      DNS_SERVICE="dns_dp"
    ;;
    *) ;;
  esac
}

acme_add_domain() {
  echo -e "Add new domain Let's Encrypt SSL certificate..."

  # Input Aliyun AccessKey
  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input your domain (eg. domain.com, NOT subdomain): " add_domain
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input certificate folder (eg. /etc/nginx/cert): " ng_cert_dir
  echo ""

  # regist wildcard domain
  random_record=`fun_randstr`
  ~/.acme.sh/acme.sh --issue --dns ${DNS_SERVICE} -d ${add_domain} -d *.${add_domain} -d *.${random_record}.${add_domain} --yes-I-know-dns-manual-mode-enough-go-ahead-please --force

  # Check certificate exist
  if [ ! -f ~/.acme.sh/${add_domain}/${add_domain}.cer ]; then
    echo -e "${ERROR} Generate certificate failure!!!"
    exit 3
  else
    mkdir -p ${ng_cert_dir}

    # Install certificate to target folder
    ~/.acme.sh/acme.sh --installcert -d ${add_domain} --fullchainpath ${ng_cert_dir}/${add_domain}.crt --keypath ${ng_cert_dir}/${add_domain}.key --reloadcmd "service nginx force-reload"
  fi
}


main() {
  echo ""
  echo -e "Which one do you want to do?"
  echo "1. Install acme.sh"
  echo "2. Add domain"
  echo "3. Refresh domains"
  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Input the number and press enter. (Press any other key to exit) " num

  case "${num}" in
    [1] ) (acme_install);;
    [2] )
      choose_service
      acme_configure_check
      acme_add_domain
    ;;
    [3] )
      LOGIN_USER=`users`
      ~/.acme.sh/acme.sh --cron --home "/${LOGIN_USER}/.acme.sh" --force
    ;;
    *) echo "Bye~~~";;
  esac
}

main