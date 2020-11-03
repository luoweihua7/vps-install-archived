#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

fun_randstr() {
    index=0
    strRandomPass=""
    for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {1..16}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
    echo $strRandomPass
}

setup_firewall() {
    echo "Seting up firewall..."
    systemctl enable firewalld
    systemctl start firewalld
    firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p icmp -s 0.0.0.0/0 -d 0.0.0.0/0 -j ACCEPT
    firewall-cmd --permanent --zone=public --add-port=22/tcp
    firewall-cmd --permanent --zone=public --add-port=80/tcp
    firewall-cmd --permanent --zone=public --add-port=443/tcp
    firewall-cmd --permanent --zone=public --add-port=6800/tcp
    firewall-cmd --permanent --zone=public --add-port=6881-6999/tcp
    firewall-cmd --permanent --zone=public --add-port=6881-6999/udp
    firewall-cmd --permanent --zone=public --add-port=9736/tcp
    firewall-cmd --permanent --zone=public --add-port=9736/udp
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

mount_data_disk() {
    mount /dev/vdb1 /data
    echo "/dev/vdb1  /data ext4 defaults  0  0" >> /etc/fstab
}

install_nginx() {
    rpm -ivh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
    yum install nginx -y
    systemctl enable nginx.service
}

install_redis_epel() {
    rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    yum install redis -y
    systemctl start redis
    systemctl enable redis
}

install_redis() {
    rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    rpm -Uvh http://rpms.remirepo.net/enterprise/7/remi/x86_64/remi-release-7.7-2.el7.remi.noarch.rpm
    yum --enablerepo=remi install redis -y

    RANDOM=`fun_randstr`
    REDIS_PWD=`echo "$RANDOM" | sha256sum | awk '{print $1}'`

    sed -i -e "s/^bind 127.0.0.1/# bind 0.0.0.0/g" /etc/redis.conf
    sed -i -e "s/^port/# port/g" /etc/redis.conf

    echo "
# Server configuration

bind 0.0.0.0
requirepass $REDIS_PWD
port 9736
rename-command FLUSHALL \"FLUSHALL_$RANDOM\"
rename-command CONFIG   \"\"
rename-command EVAL     \"\"" >> /etc/redis.conf

    service redis restart
}

install_node() {
    curl -sL --location https://rpm.nodesource.com/setup_14.x | bash -
    yum install -y nodejs
}


setup() {
    setup_firewall
    setup_ssh
    setup_tcp_hybla
    mount_data_disk
    install_nginx
    install_redis
    install_node
}

setup