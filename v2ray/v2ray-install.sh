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


# Parameters

ntp_update() {
  ntpdate time.nist.gov
}

install_v2ray_core() {
  bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
}

update_geo_dat() {
  bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-dat-release.sh)
}

uninstall_v2ray_core() {
  bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
}

setup_ssl() {
  local is_acme_installed=``
}

configure_v2ray() {
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
" > /usr/local/etc/v2ray/config.json
}