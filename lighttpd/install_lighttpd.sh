wget --no-check-certificate https://github.com/luoweihua7/vps-install/raw/master/lighttpd/lighttpd.tar.gz -O /tmp/lighttpd.tar.gz
tar zxvf /tmp/lighttpd.tar.gz -C /koolshare/

wget --no-check-certificate https://github.com/luoweihua7/vps-install/raw/master/lighttpd/lighttpd_check.sh -O /koolshare/scripts/lighttpd_check.sh
echo "sh /koolshare/scripts/lighttpd_check.sh" >> /jffs/scripts/wan-start
sh /koolshare/scripts/lighttpd_check.sh

rm -rf /tmp/lighttpd.tar.gz
