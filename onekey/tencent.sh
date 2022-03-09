#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

GITHUB_URL="https://raw.githubusercontent.com/luoweihua7/vps-install/master/"

download() {
    wget --no-check-certificate --no-cache -cq -t3 ${2} -O ${1}
}

uninstall_qcloud() {
    echo "Uninstall Tencent Cloud services..."
    sh /usr/local/qcloud/stargate/admin/uninstall.sh >> /dev/null 2>&1
    sh /usr/local/qcloud/YunJing/uninst.sh >> /dev/null 2>&1
    sh /usr/local/qcloud/monitor/barad/admin/uninstall.sh >> /dev/null 2>&1
    echo "Tencent Cloud services uninstalled."
}

setup_firewall() {
    echo "Seting up firewall..."
    systemctl enable firewalld
    systemctl start firewalld
    firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p icmp -s 0.0.0.0/0 -d 0.0.0.0/0 -j ACCEPT
    # SSH default
    firewall-cmd --permanent --zone=public --add-port=22/tcp
    # HTTP/HTTPS
    firewall-cmd --permanent --zone=public --add-port=80/tcp
    firewall-cmd --permanent --zone=public --add-port=443/tcp
    # 55服务
    firewall-cmd --permanent --zone=public --add-port=5555/tcp
    firewall-cmd --permanent --zone=public --add-port=5555/udp
    # ARIA
    firewall-cmd --permanent --zone=public --add-port=6800/tcp
    # DHT
    firewall-cmd --permanent --zone=public --add-port=6881-6999/tcp
    firewall-cmd --permanent --zone=public --add-port=6881-6999/udp
    # X-UI
    firewall-cmd --permanent --zone=public --add-port=20001-20005/tcp
    firewall-cmd --permanent --zone=public --add-port=20001-20005/udp
    # SSH
    firewall-cmd --permanent --zone=public --add-port=26538/tcp
    firewall-cmd --permanent --zone=public --add-port=26538/udp

    firewall-cmd --reload
    echo "firewall setup finished."
}

setup_ssh() {
    echo "Seting up ssh..."
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCuuDQDsn4dWXdmpVrO04yLc4ukE1lACuCdc6o5TTWvNQs7R6BTYrJDxDo0obJHFMaPQ755U5TcoeVP/5P7prsZxKqKrcKSU1G1MPyybXSW7vgvu5zyX65L470S983bM+1sIZT9LtBmnur+Fw80wCPMt70AQ+/URxenmcFr4F8V5eggUZdOF6vpPXDTDs3dXV26gD8Hw/oMwUpkRw7u7Lt2aKcPx/H9ocS4TBFVQRLC2R14rMWOjMNNuYt4dQsi+tCwruf2dYQVLbhxgDWuU6dZd2sdppOuTk+j5uvG/4ONJAvtTWM2FCrRk2DKHDYgntcr37ZNtF2zHjNYRz935Un/ luoweihua7@gmail.com" > ~/.ssh/authorized_keys
    sed -i -e "s/#Port 22/Port 26538/g" /etc/ssh/sshd_config
    sed -i -e "s/#PubkeyAuthentication/PubkeyAuthentication/g" /etc/ssh/sshd_config
    sed -i -e "s/#AllowTcpForwarding/AllowTcpForwarding/g" /etc/ssh/sshd_config
    sed -i -e "s/#AllowAgentForwarding/AllowAgentForwarding/g" /etc/ssh/sshd_config
    sed -i -e "s/#TCPKeepAlive/TCPKeepAlive/g" /etc/ssh/sshd_config
    sed -i -e "s/#PasswordAuthentication/PasswordAuthentication/g" /etc/ssh/sshd_config
    systemctl restart sshd
    echo "ssh setup finished."
}

setup_tcp_hybla() {
    echo "Seting up BBR..."
    /sbin/modprobe tcp_hybla

    echo "
# hybla
fs.file-max = 51200
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = hybla" >> /etc/sysctl.conf

    sysctl -p >> /dev/null
    echo "BBR setup finished."
}

update_wget() {
    echo "Installing require dependents, please wait..."
    yum install -y openssl-devel openssl git unzip

    wget http://mirrors.ustc.edu.cn/gnu/wget/wget-latest.tar.gz
    mkdir /tmp/wget-latest
    tar xvf wget-latest.tar.gz -C /tmp/wget-latest --strip-components 1 >> /dev/null 2>&1
    cd /tmp/wget-latest
    ./configure --prefix=/usr --sysconfdir=/etc --with-ssl=openssl
    make && make install
    cd ~/
    rm -rf /tmp/wget-latest
    rm -rf wget-latest.tar.gz
}

config_bashrc() {
  echo "
export PS1=\"\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w\[\033[m\]\$ \"" >> /etc/bashrc

  source /etc/bashrc
}

install_nginx() {
    rpm -ivh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
    yum install nginx -y
    systemctl enable nginx.service
    service nginx start

    # Change nginx default pages
    echo ""
    echo -e "Downloading custom pages..."
    pages=(
        index.html
        40x.html
        50x.html
    )
    for ((i=1;i<=${#pages[@]};i++ )); do
        hint="${pages[$i-1]}"
        rm -rf /usr/share/nginx/html/${hint}
        download "/usr/share/nginx/html/${hint}" "https://raw.githubusercontent.com/luoweihua7/vps-install/master/nginx/html/${hint}"
    done

    sed -i -e "s/#error_page/error_page/g" /etc/nginx/conf.d/default.conf >> /dev/null 2>&1
    sed -i -e "s/404.html/40x.html/g" /etc/nginx/conf.d/default.conf >> /dev/null 2>&1
    nginx -s reload

    echo "Nginx default page changed!"
    echo ""
}

setup() {
    update_wget
    uninstall_qcloud
    setup_firewall
    setup_ssh
    setup_tcp_hybla
    config_bashrc

    install_nginx
}

setup