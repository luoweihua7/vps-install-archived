
wget --no-check-certificate https://github.com/luoweihua7/vps-install/raw/master/lighttpd/lighttpd.tar.gz -O /tmp/lighttpd.tar.gz
wget --no-check-certificate 
tar zxvf /tmp/lighttpd.tar.gz -C /koolshare/
rm -rf /tmp/lighttpd.tar.gz
echo "sh /koolshare/scripts/lighttpd_check.sh" >> /jffs/scripts/wan-start
