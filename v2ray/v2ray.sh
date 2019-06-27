#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Message
INFO="${green}[信息]${plain}"
WARN="${yellow}[警告]${plain}"
ERROR="${red}[错误]${plain}"
SUCCESS="${green}[SUCCESS]${plain}"

# Path
v2ray_conf_dir="/etc/v2ray"
nginx_conf_dir="/etc/nginx/conf.d"
v2ray_conf="${v2ray_conf_dir}/config.json"
nginx_conf="${nginx_conf_dir}/v2ray.conf"

preinstall() {
  echo -e "${INFO} 正在安装依赖包"
  # qrencode 是生成二维码用的
  yum install wget git lsof crontabs bc unzip qrencode -y
}

ntpdate_install() {
  echo -e "${INFO} 正在安装ntpdate"
  yum install ntpdate -y
  systemctl stop ntp &>/dev/null

  echo -e "${INFO} 正在进行时间同步"
  ntpdate time.nist.gov

  if [[ $? -eq 0 ]];then 
    echo -e "${INFO} 时间同步成功"
    echo -e "${INFO} 当前服务器时间: `date -R`"
    sleep 1
  else
    echo -e "${ERROR} 时间同步失败，请检查ntpdate服务是否正常工作"
  fi 
}

v2ray_install() {
  echo -e "${INFO} 正在安装V2Ray"
  if [[ -d /root/v2ray ]]; then
    rm -rf /root/v2ray
  fi

  mkdir -p /root/v2ray && cd /root/v2ray
  bash <(curl -L -s https://install.direct/go.sh)
  echo -e "${INFO} V2Ray 安装完成"
}

check_port() {
  if [[ 0 -eq `lsof -i:"$1" | wc -l` ]];then
    echo -e "${INFO} $1 端口未被占用 ${Font}"
    sleep 1
  else
    echo -e "${ERROR} 检测到 $1 端口被占用，以下为 $1 端口占用信息 ${Font}"
    lsof -i:"$1"
    sleep 1
    return 1
  fi
}

ssl_install() {
  echo -e "${INFO} 正在安装依赖包"
  yum install socat nc -y
  curl  https://get.acme.sh | sh


}

v2ray_config() {
  # 下载默认配置
  wget --no-check-certificate --no-cache -cq -t3 "https://raw.githubusercontent.com/luoweihua7/vps-install/master/v2ray/config/server.json" -O ${v2ray_conf}

  # 替换为用户的设置
  # 域名
  stty erase '^H' && read -p "请输入指向本机的域名地址(例如: www.example.com):" domain
  local_ip=`curl -4 ip.sb`

  while true
  do
  echo ""
  read -p "请输入V2Ray服务端端口 (默认: ): " PORT
  [ -z "$PORT" ] && PORT=$default_port
  expr $PORT + 0 &>/dev/null
  if [ $? -eq 0 ]; then
      if [ $PORT -ge 1 ] && [ $PORT -le 65535 ]; then
          break
      else
          echo -e "\033[41;37m ERROR \033[0m Input error! Please input correct numbers."
      fi
  else
      echo -e "\033[41;37m ERROR \033[0m Input error! Please input correct numbers."
  fi
  done

  # 端口
  stty erase '^H' && read -p "请输入连接端口（默认: 443）:" port
  [[ -z ${port} ]] && port="443"
  stty erase '^H' && read -p "请输入alterId（默认: 32, 建议30-100之间）:" alter_id
  [[ -z ${alter_id} ]] && alter_id="64"
}

show_qrcode() {
  # yum install qrencode 
}