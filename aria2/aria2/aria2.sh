#!/bin/sh
### BEGIN INIT INFO
# Provides: aria2
# Required-Start: $remote_fs $network
# Required-Stop: $remote_fs $network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Aria2 Downloader
### END INIT INFO

start() {
  echo -n "Starting aria2c"
  /usr/local/bin/aria2c --conf-path=/home/conf/aria2/aria2.conf -D
  echo ""
}

stop() {
  echo -n "Shutting down aria2c"
  pid=`ps aux | grep "/usr/local/bin/aria2c" | grep -v "grep" | awk '{print $2}'`
  if [ ! $pid ]; then
    echo "Service aria2c not runing."
  else 
    if ps -p $pid > /dev/null ; then
      kill -9 $pid
    fi
  fi
  echo ""
}

case "$1" in
start)
  start
  ;;
stop)
  stop
  ;;
restart)
  stop
  sleep 1
  start
  ;;
esac
exit