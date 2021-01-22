#!/bin/sh
### BEGIN INIT INFO
# Provides: shadowsocks
# Required-Start: $remote_fs $network
# Required-Stop: $remote_fs $network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: shadowsocks-libev
### END INIT INFO

conf_file_path="SS_CONF_DIR"

start() {
  if [ -d $conf_file_path ]; then
    echo "Starting up shadowsocks-libev service..."
    for f in $conf_file_path/* ; do
      pid=`ps aux | grep "$f" | grep -v "grep" | awk '{print $2}'`
      if [ ! $pid ]; then
        nohup /usr/bin/ss-server -u -c $f > /dev/null 2>&1 &
      else
        echo "Service already started. ($f)"
      fi
    done
  else
    echo "error: $conf_file_path directory not found" >&2
    exit 1
  fi
}

stop() {
  if [ -d $conf_file_path ]; then
    echo "Shuting down shadowsocks-libev service..."
    for f in $conf_file_path/* ; do
      pid=`ps aux | grep "$f" | grep -v "grep" | awk '{print $2}'`
      if [ ! $pid ]; then
        echo "Related processes not found ($f)."
      else 
        if ps -p $pid > /dev/null ; then
          kill -9 $pid
        fi
      fi
    done
  else
    echo "error: $conf_file_path directory not found" >&2
    exit 1
  fi
}

restart() {
  stop
  start
}

case "$1" in
  start)
    start
  ;;
  stop)
    stop
  ;;
  restart)
    restart
  ;;
  cleanup)
  ;;
  *)
  echo $"Usage: $0 {start|stop|restart}"
  exit 1
esac

exit $?
