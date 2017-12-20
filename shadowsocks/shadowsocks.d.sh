#!/bin/sh

start() {
  if [ -d /home/conf/shadowsocks/ ]; then
    echo "Launching shadowsocks initialization scripts"
    for f in /home/conf/shadowsocks/* ; do
      pid=`ps aux | grep "$f" | grep -v "grep" | awk '{print $2}'`
      if [ ! $pid ]; then
        nohup /usr/bin/ss-server -c $f > /dev/null 2>&1 &
      fi
    done
  else
    echo "error: /home/conf/shadowsocks/ directory not found" >&2
    exit 1
  fi
}

stop() {
  if [ -d /home/conf/shadowsocks/ ]; then
    echo "Launching shadowsocks termination scripts"
    for f in /home/conf/shadowsocks/* ; do
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
    echo "error: /home/conf/shadowsocks/ directory not found" >&2
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
