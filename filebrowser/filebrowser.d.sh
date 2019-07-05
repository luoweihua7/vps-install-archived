#!/bin/sh
### BEGIN INIT INFO
# Provides: filebrowser
# Required-Start: $remote_fs $network
# Required-Stop: $remote_fs $network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: File Browser
### END INIT INFO

start() {
  echo -n "Starting filebrowser service..."
  nohup /usr/local/bin/filebrowser -d DBCONF > /dev/null 2>&1 &
  echo ""
}

stop() {
  echo "Stopping filebrowser service..."
  pid=`ps aux | grep "/usr/local/bin/filebrowser" | grep -v "grep" | awk '{print $2}'`
  if [ ! $pid ]; then
    echo "Service filebrowser not runing."
  else 
    if ps -p $pid > /dev/null ; then
      kill -9 $pid
    fi
  fi
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