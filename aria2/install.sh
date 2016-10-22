#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cd /tmp
wget --no-check-certificate https://github.com/luoweihua7/vps-install/raw/master/aria2/aria2.tar.gz
tar zxvf aria2.tar.gz -C /usr/local/

echo 'nohup /usr/local/aria2/aria2c --conf-path=/usr/local/aria2/aria2.conf >> /var/log/aria2.log &' >> /etc/rc.local

echo 'Aria2 installed'
