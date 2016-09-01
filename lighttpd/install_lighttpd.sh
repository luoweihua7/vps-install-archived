wget --no-check-certificate https://github.com/luoweihua7/vps-install/raw/master/lighttpd/lighttpd.tar.gz -O /tmp/lighttpd.tar.gz
tar zxvf /tmp/lighttpd.tar.gz -C /koolshare/

mv /koolshare/lighttpd/S92lighttpd.sh /koolshare/init.d/
sh /koolshare/init.d/S92lighttpd.sh restart

rm -rf /tmp/lighttpd.tar.gz
