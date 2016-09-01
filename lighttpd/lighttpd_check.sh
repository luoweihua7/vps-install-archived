#!/bin/sh
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
lighttpd_run=$(ps|grep lighttpd|grep -v grep)
if [ ! -z "$lighttpd_run" ];then
	echo lighttpd is running!
	logger [ '$LOGTIME' ] lighttpd is running!
else
	logger [ '$LOGTIME' ] start lighttpd...
	/usr/sbin/lighttpd -f /koolshare/lighttpd/lighttpd.conf
fi
