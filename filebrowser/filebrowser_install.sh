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
IS_NGINX=""
NG_CONF_DIR="/etc/nginx/conf.d/"
NG_CONF="${NG_CONF_DIR}default.conf"

GIT_URL="https://raw.githubusercontent.com/luoweihua7/vps-install/master"

FB_DB="filebrowser.db"
FB_CONF_DIR="/data/conf/filebrowser"
FB_BASEURL=""
FB_WEB_PORT="80"
FB_USER="admin"
FB_PWD=""
FB_ROOT_DIR=""
FB_URL=""

fun_randstr(){
    index=0
    strRandomPass=""
    for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {1..16}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
    echo $strRandomPass
}

add_firewall() {
  PORT=$1
  echo -e "Adding firewall port ${PORT} ..."
  firewall-cmd --permanent --zone=public --add-port=$PORT/tcp -q
  firewall-cmd --permanent --zone=public --add-port=$PORT/udp -q
  firewall-cmd --reload -q
  echo -e "Filewall port ${PORT} added."
}

nginx_config() {
  local LOCAL_IP=`curl -4 -s ip.sb`
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Would you want to configure nginx? Y/n: " IS_NGINX
  [ -z "${IS_NGINX}" ] && IS_NGINX="Y"

  case ${IS_NGINX} in
    [yY][eE][sS]|[yY])
      echo ""
      echo -e "Select the access mode:"
      echo "1. Use subpath like www.domain.com/pathto"
      echo "2. Use subdomain like file.domain.com."

      while true
      do
        stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please select (default: 1) " nginx_mode
        [ -z "${nginx_mode}" ] && nginx_mode=1
        if [ 1 -eq ${nginx_mode} ];then
          # Subpath mode
          if [ -e ${NG_CONF} ]; then
            stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input subpath (default: files) " baseurl
            if [ -z "${baseurl}" ]; then
              FB_BASEURL="files"
            else
              FB_BASEURL=${baseurl}
            fi
            echo ""
            sed -i "/error_page *404 */i\    location /${FB_BASEURL} {\n        proxy_pass http://127.0.0.1:${FB_WEB_PORT};\n    }\n" ${NG_CONF}
            FB_URL="http://${LOCAL_IP}/${FB_BASEURL}"
          else
            echo "Nginx default config file (${NG_CONF}) not exist."
          fi
          break
        elif [ 2 -eq ${nginx_mode} ]; then
          # Subdomain mode
          stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input subdomain (eg. filebrowser.example.com) " hostname

          local nginx_conf="${hostname}.conf"
          wget --no-check-certificate --no-cache -cq -t3 "${GIT_URL}/filebrowser/nginx.conf" -O ${NG_CONF_DIR}${nginx_conf}
          sed -i -e "s/FB_DOMAIN/${hostname}/g" ${NG_CONF_DIR}${nginx_conf}
          sed -i -e "s/FB_WEB_PORT/${FB_WEB_PORT}/g" ${NG_CONF_DIR}${nginx_conf}

          FB_URL="http://${hostname}"
          break
        else
          echo -e "${WARN} Port ${web_port} looks like running service, try another one..."
        fi
      done
      ;;
    *)
      FB_URL="http://${LOCAL_IP}:${FB_WEB_PORT}"
      ;;
  esac
}

fb_config() {
  # prepare package
  local lsof_installed=`rpm -qa | grep lsof | wc -l`
  if [ ${lsof_installed} -ne 0 ]; then
    echo "Installing require dependents, please wait..."
    yum install lsof -y &>/dev/null
  fi

  echo ""
  # Database file path
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input filebrowser database path (eg: /etc): " conf_dir

  # Listen port
  echo ""
  local v2port=4443
  while true
  do
    local rand_port=`shuf -i 10000-59999 -n 1`
    stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input filebrowser port to listen on (default: ${rand_port}): " web_port
    [ -z "${web_port}" ] && web_port=${rand_port}
    if [[ 0 -eq `lsof -i:"${rand_port}" | wc -l` ]];then
      expr ${web_port} + 0 &>/dev/null
      break
    else
      echo -e "${WARN} Port ${web_port} looks like running service, try another one..."
    fi
  done

  echo ""
  # Database file path
  while true
  do
    stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input filebrowser ROOT path (eg: /data/wwwroot): " root_dir
    if [ -z "$root_dir" ]; then
      echo "ROOT path required, please input "
    else
      break
    fi
  done

  echo ""
  local default_user="admin"
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input filebrowser username (default: ${default_user}): " username
  [ -z "${username}" ] && username=${default_user}

  echo ""
  local default_pwd=`fun_randstr`
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input filebrowser password (default: ${default_pwd}): " password
  [ -z "${password}" ] && password=${default_pwd}

  echo ""

  # Set config
  FB_CONF_DIR=${conf_dir}
  FB_WEB_PORT=${web_port}
  FB_ROOT_DIR=${root_dir}
  FB_USER=${username}
  FB_PWD=${password}
}

install_core() {
  curl -fsSL https://filebrowser.org/get.sh | bash
}

config_filebrowser() {
  echo -e "Setting up filebrowser..."
  mkdir -p ${FB_CONF_DIR}
  local DB_PATH="${FB_CONF_DIR}/${FB_DB}"
  /usr/local/bin/filebrowser -d ${DB_PATH} config init &>/dev/null
  /usr/local/bin/filebrowser -d ${DB_PATH} config set --address 0.0.0.0 &>/dev/null
  /usr/local/bin/filebrowser -d ${DB_PATH} config set --port ${FB_WEB_PORT} &>/dev/null
  /usr/local/bin/filebrowser -d ${DB_PATH} config set --locale zh-cn &>/dev/null
  /usr/local/bin/filebrowser -d ${DB_PATH} config set --root ${FB_ROOT_DIR} &>/dev/null
  if [ -n "${FB_BASEURL}" ]; then
    /usr/local/bin/filebrowser -d ${DB_PATH} config set --baseurl /${FB_BASEURL} &>/dev/null
  fi
  /usr/local/bin/filebrowser -d ${DB_PATH} config set --log /var/log/filebrowser.log &>/dev/null
  /usr/local/bin/filebrowser -d ${DB_PATH} users add ${FB_USER} ${FB_PWD} --perm.admin &>/dev/null
  echo "Filebrowser setup completed."

  echo "Install filebrowser service..."
  local script_path="/etc/init.d/filebrowser"
  wget --no-check-certificate --no-cache -cq -t3 "${GIT_URL}/filebrowser/filebrowser.d.sh" -O /etc/init.d/filebrowser
  sleep 1
  sed -i -e "s|DBCONF|${DB_PATH}|g" /etc/init.d/filebrowser
  chmod 755 /etc/init.d/filebrowser
  chkconfig --add filebrowser
  chkconfig filebrowser on
  echo "Service installed."

  case ${IS_NGINX} in
    [yY][eE][sS]|[yY])
      ;;
    *)
      add_firewall ${FB_WEB_PORT}
      ;;
  esac
}

show_information() {
  echo ""
  echo -e "${blue_bg}   Filebrowser info   ${plain}"
  echo -e "Config Directory\t${green} ${FB_CONF_DIR} ${plain}"
  echo -e "Web Port\t\t${green} ${FB_WEB_PORT} ${plain}"
  echo -e "Root Directory\t\t${green} ${FB_ROOT_DIR} ${plain}"
  echo -e "Access URL\t\t${green} ${FB_URL} ${plain}"
  echo -e "Username\t\t${green} ${FB_USER} ${plain}"
  echo -e "Password\t\t${green} ${FB_PWD} ${plain}"
  echo ""
}

install() {
  fb_config
  nginx_config
  install_core
  config_filebrowser

  # Start service
  service filebrowser restart
  service nginx restart

  show_information
}

uninstall() {
  echo ""
  # Database file path
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Please input filebrowser database path (eg: /etc): " conf_dir
  if [ -z "${conf_dir}" ]; then
    echo "Database file path error. exit!"
  else
    if [ -e "${conf_dir}/${FB_DB}" ]; then
      rm -rf ${conf_dir}
    fi

    echo "Stopping filebrowser service..."
    pid=`ps aux | grep "/usr/local/bin/filebrowser" | grep -v "grep" | awk '{print $2}'`
    if [ ! $pid ]; then
      echo "Service filebrowser not runing."
    else 
      if ps -p $pid > /dev/null ; then
        kill -9 $pid
      fi
    fi

    echo "Removing relate files"
    rm -rf /usr/local/bin/filebrowser

    systemctl stop filebrowser
    systemctl disable filebrowser
    rm -rf /etc/systemd/system/filebrowser.service
    rm -rf /etc/init.d/filebrowser
    systemctl daemon-reload
    echo -e "${WARN} Please remove nginx config manually."
    echo "Filebrowser uninstalled."
  fi
}

main() {
  echo ""
  echo -e "Which one do you want to do?"
  echo "1. Install File Browser"
  echo "2. Uninstall File Browser"
  echo ""
  stty erase '^H' && stty erase ^? && read -p "${READ_INFO} Input the number and press enter. (Press any other key to exit) " num

  case "${num}" in
    [1] ) (install);;
    [2] ) (uninstall);;
    *) echo "Bye~~~";;
  esac
}

main