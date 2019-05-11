#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

uninstall_aliyun() {
    echo "Uninstall Aliyun services..."
    for aliyun_pid in `ps axf | grep aliyun | grep -v grep | awk {'print $1'}`
    do
        kill -9 $aliyun_pid
        echo "kill -9 $aliyun_pid"
    done

    curl -sSL http://update.aegis.aliyun.com/download/quartz_uninstall.sh | sudo bash
    rm -rf /usr/local/aegis
    rm -rf /usr/local/share/aliyun*
    rm -rf /usr/sbin/aliyun*
    rm -rf /etc/init.d/agentwatch

    systemctl stop aliyun.service
    systemctl disable aliyun.service
    systemctl delete aliyun.service
    killall aliyun-service
    echo "Aliyun services uninstalled."
}

setup_firewall() {
    echo "Seting up firewall..."
    systemctl enable firewalld
    systemctl start firewalld
    firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p icmp -s 0.0.0.0/0 -d 0.0.0.0/0 -j ACCEPT
    firewall-cmd --permanent --zone=public --add-port=22/tcp
    firewall-cmd --permanent --zone=public --add-port=80/tcp
    firewall-cmd --permanent --zone=public --add-port=443/tcp
    firewall-cmd --permanent --zone=public --add-port=5555/tcp
    firewall-cmd --permanent --zone=public --add-port=5555/udp
    firewall-cmd --permanent --zone=public --add-port=6800/tcp
    firewall-cmd --permanent --zone=public --add-port=6881-6999/tcp
    firewall-cmd --permanent --zone=public --add-port=6881-6999/udp
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

setup() {
    uninstall_aliyun
    setup_firewall
    setup_ssh
    setup_tcp_hybla
}

setup