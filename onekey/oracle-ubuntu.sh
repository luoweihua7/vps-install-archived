# 防火墙配置（除了设置子网里面的安全规则列表之外，还需要处理服务器的iptables规则）
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F

# 卸载防火墙和配置
apt purge -y netfilter-persistent
# 更新并安装组件
apt update -y
apt install -y curl socat ntpdate net-tools nginx

fun_randstr() {
    echo $RANDOM | md5sum | cut -c 1-6
}

fun_randnum() {
  local randnum=8443
  while true
  do
    local rand_port=`shuf -i 10000-59999 -n 1`
    if [ 0 -eq `lsof -i:"${rand_port}" | wc -l` ];then
      randnum="${rand_port}"
      break
    fi
  done
  echo ${randnum}
}

fun_uund() {
  echo `cat /proc/sys/kernel/random/uuid`
}

# 安装v2ray
curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh | bash

# 安装acme
curl https://get.acme.sh | sh

# 配置Nginx
echo ""
read -p "Please input your domain (eg. domain.com, NOT subdomain): " domain

echo ""
read -p "Please input xray service subdomain (eg. sg.domain.com): " vmess_domain

echo ""
read -p "Please input Aliyun AccessKey ID: " alikey

echo ""
read -p "Please input Aliyun AccessKey Secret: " alisecret

ssl_dir="/etc/ssl/private"
v2port=`fun_randnum`
v2path=`fun_randstr`
v2uuid=`fun_uund`

echo "
server {
    listen                443 ssl;
    ssl_certificate       ${ssl_dir}/${domain}.crt;
    ssl_certificate_key   ${ssl_dir}/${domain}.key;
    ssl_protocols         TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers           HIGH:!aNULL:!MD5;
    server_name           ${vmess_domain};
    index                 index.html index.htm;
    root                  /usr/share/nginx/html;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    location /${v2path} {
        if (\$http_upgrade != \"websocket\") {
          return 404;
        }
        proxy_pass http://127.0.0.1:${v2port};
        proxy_redirect      off;
        proxy_http_version  1.1;
        proxy_set_header    Upgrade \$http_upgrade;
        proxy_set_header    Connection \"upgrade\";
        proxy_set_header    Host \$http_host;
        proxy_read_timeout  300s;
        proxy_set_header    X-Real-IP \$remote_addr;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}

server {
    listen 80;
    server_name ${vmess_domain};
    return 301 https://\$host\$request_uri;
}
" > /etc/nginx/conf.d/${domain}.conf

# 配置v2ray
echo "
{
  \"log\": {
    \"loglevel\": \"warning\",
    \"access\": \"/var/log/v2ray/access.log\",
    \"error\": \"/var/log/v2ray/error.log\"
  },
  \"inbounds\": [
    {
      \"port\": ${v2port},
      \"listen\": null,
      \"tag\": \"vmess-in\",
      \"protocol\": \"vmess\",
      \"settings\": {
        \"clients\": [
          {
            \"id\": \"${v2uuid}\",
            \"alterId\": 0
          }
        ],
        \"disableInsecureEncryption\": false
      },
      \"streamSettings\": {
        \"network\": \"ws\",
        \"security\": \"none\",
        \"wsSettings\": {
          \"path\": \"/${v2path}\",
          \"headers\": {}
        }
      },
      \"sniffing\": {
        \"enabled\": true,
        \"destOverride\": [
          \"http\",
          \"tls\"
        ]
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

# 配置证书
export Ali_Key="${alikey}"
export Ali_Secret="${alisecret}"
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue --dns dns_ali -d ${domain} -d ${vmess_domain} -d *.${v2path}.${domain} --yes-I-know-dns-manual-mode-enough-go-ahead-please --force
~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/ssl/private/${domain}.crt --keypath /etc/ssl/private/${domain}.key --reloadcmd "service nginx force-reload"

# 重启服务
service v2ray restart
service nginx restart

# 输出配置信息
local_ip=`curl -4 -s ip.sb`
## ClashX
echo ""
echo "===== ClashX ====="
echo "- { name: \"VMESS-${v2path}\", type: vmess, server: ${vmess_domain}, port: 443, uuid: ${v2uuid}, alterId: 64, cipher: auto, network: ws, ws-path: /${v2path}, tls: true }"
echo ""
## Shadowrocket
echo "===== Shadowrocket ====="
echo "vmess://`echo -n 'none:'${v2uuid}'@'${local_ip}':443' | base64 -w 0`?remarks=VMESS&path=/${v2path}&obfs=websocket&tls=1"
echo ""
## QuantumultX
echo "===== QuantumultX ====="
echo "vmess=${vmess_domain}:443, method=aes-128-gcm, password=${v2uuid}, obfs=wss, obfs-uri=/${v2path}, fast-open=false, udp-relay=false, tag=vmess"
echo "vmess=${local_ip}:443, method=none, password=${v2uuid}, obfs=wss, obfs-host=${vmess_domain}, obfs-uri=/${v2path}, fast-open=false, udp-relay=false, tag=vmess"
## 完成，提示可能需要设置防火墙以让端口连通
echo ""
echo "Please add the configuration manually"
echo ""
echo "*** If server firewall enabled, please configure firewall rules manually first ***"
echo ""