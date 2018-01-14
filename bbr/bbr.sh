#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

BBR_DL_URL="https://github.com/linhua55/lkl_study/releases/download/v1.2/rinetd_bbr_powered"

function progressfilter () {
    local flag=false c count cr=$'\r' nl=$'\n'
    while IFS='' read -d '' -rn 1 c
    do
        if $flag
        then
            printf '%c' "$c"
        else
            if [[ $c != $cr && $c != $nl ]]
            then
                count=0
            else
                ((count++))
                if ((count > 1))
                then
                    flag=true
                fi
            fi
        fi
    done
}

function add_config() {
    mkdir /home/conf/bbr -p

    echo ""
    read -p "Input ports you want to speed up (eg. 8080 8081 8082): " PORTS </dev/tty
    for d in $PORTS
    do          
    cat <<EOF >> /home/conf/bbr/rinetd-bbr.conf
0.0.0.0 $d 0.0.0.0 $d 
EOF
    done

    service rinetd restart
    echo "All done!"
}

function add_startup_script() {
    cat > /etc/init.d/rinetd <<-EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides: rinetd
# Required-Start: $remote_fs $network
# Required-Stop: $remote_fs $network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: rintd bbr
### END INIT INFO

IFACE=\$(ip -4 addr | awk '{if (\$1 ~ /inet/ && \$NF ~ /^[ve]/) {a=\$NF}} END{print a}')

case "\$1" in
start)
  echo -n "Starting rinetd"
  /usr/bin/rinetd-bbr -f -c /home/conf/bbr/rinetd-bbr.conf raw \${IFACE} > /dev/null 2>\&1 &
  ;;
stop)
  echo -n "Shutting down rinetd "
  killall -q rinetd-bbr ;;
restart)
  killall -q rinetd-bbr
  /usr/bin/rinetd-bbr -f -c /home/conf/bbr/rinetd-bbr.conf raw \${IFACE} > /dev/null 2>\&1 &
  ;;
*)
  echo "Usage: rinetd {start|stop|restart}"
esac
exit
EOF

    chmod a+x /etc/init.d/rinetd
    chkconfig --add rinetd
    chkconfig rinetd on

    echo "Rinetd config file created."
}

function install_rinetd() {
    echo "Downloading rinetd-bbr..."
    wget --no-check-certificate --progress=bar:force $BBR_DL_URL -O /usr/bin/rinetd-bbr 2>&1 | progressfilter
    chmod a+x /usr/bin/rinetd-bbr
    echo "rinetd-bbr downloaded."
}

function install() {
    install_rinetd
    add_startup_script
    add_config
}

function uninstall() {
    echo "Killing process..."
    killall -q rinetd-bbr
    echo "Removing files..."
    rm -rf /usr/bin/rinetd-bbr
    rm -rf /etc/init.d/rinetd
    rm -rf /home/conf/bbr
    echo "All done!"
    echo ""
}


if [ "$(id -u)" != "0" ]; then
    echo "ERROR: Please run as root"
    exit 1
fi

# for CMD in wget iptables
# do
# 	if ! type -p ${CMD}; then
# 		echo -e "\e[1;31mtool ${CMD} is not installed, abort.\e[0m"
# 		exit 1
# 	fi
# done

echo ""
echo "Which do you want to?"
echo "1. Install rinetd"
echo "2. Uninstall rinetd"
read -p "Please input the number and press enter.  (Press other key to exit): " num

case "$num" in
[1] ) (install);;
[2] ) (uninstall);;
*) echo "Bye~~~";;
esac