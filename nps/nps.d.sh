#!/bin/sh
### BEGIN INIT INFO
# Provides: nps
# Required-Start: $remote_fs $network
# Required-Stop: $remote_fs $network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: nps server
### END INIT INFO

start() {
  service nps start
}

stop() {
  service nps stop
}

restart() {
  service nps restart
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
