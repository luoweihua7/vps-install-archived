#!/bin/sh
### BEGIN INIT INFO
# Provides: nps
# Required-Start: $remote_fs $network
# Required-Stop: $remote_fs $network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: nps server
### END INIT INFO

nps_path="/usr/local/nps/nps"

start() {
  echo "Starting NPS service..."
  ret=`${nps_path} start`
  echo "NPS service started."
}

stop() {
  echo "Stopping NPS service..."
  ret=`${nps_path} stop`
  echo "NPS service stoped."
}

restart() {
  echo "Restarting NPS service..."
  ret=`${nps_path} restart`
  echo "NPS service restarted."
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
