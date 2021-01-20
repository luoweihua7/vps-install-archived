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

NGINX_CONF_DIR="/etc/nginx/cert"

acme_install() {
  echo -e "Installing Let's Encrypt SSL certificate..."
  curl  https://get.acme.sh | sh

  # Input Aliyun AccessKey
  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input Aliyun AccessKey ID: " access_key
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input Aliyun Access Key Secret: " access_secret
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input your domain (eg. domain.com, NOT subdomain): " root_domain
  echo ""

  export Ali_Key="${access_key}"
  export Ali_Secret="${access_secret}"

  ~/.acme.sh/acme.sh --issue --dns dns_ali -d ${root_domain} -d *.${root_domain} --yes-I-know-dns-manual-mode-enough-go-ahead-please

  # Check certificate exist
  if [ ! -f ~/.acme.sh/${root_domain}/${root_domain}.cer ]; then
    echo -e "${ERROR} Generate certificate failure!!!"
    exit 3
  else
    mkdir -p ${NGINX_CONF_DIR}

    # Install certificate to target folder
    ~/.acme.sh/acme.sh --installcert -d ${root_domain} --fullchainpath ${NGINX_CONF_DIR}/${root_domain}.crt --keypath ${NGINX_CONF_DIR}/${root_domain}.key --reloadcmd "service nginx force-reload"
  fi
}

acme_add_domain() {
  echo -e "Installing Let's Encrypt SSL certificate..."
  curl  https://get.acme.sh | sh

  # Input Aliyun AccessKey
  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input your domain (eg. domain.com): " add_domain
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input certificate folder (eg. /etc/nginx/cert): " ng_cert_dir
  echo ""

  ~/.acme.sh/acme.sh --issue --dns dns_ali -d ${add_domain}

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
  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Input the number and press enter. (Press any other key to exit) " num

  case "${num}" in
    [1] ) (acme_install);;
    [2] ) (acme_add_domain);;
    *) echo "Bye~~~";;
  esac
}

main