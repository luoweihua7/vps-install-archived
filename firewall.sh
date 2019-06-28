#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

PORT=""

add() {
    echo -e "Add firewall port: $PORT"

    firewall-cmd --permanent --zone=public --add-port=$PORT/tcp -q
    firewall-cmd --permanent --zone=public --add-port=$PORT/udp -q
    firewall-cmd --reload -q
}

remove() {
    echo -e "Removing firewall port: $PORT"

    firewall-cmd --permanent --zone=public --remove-port=$PORT/tcp -q
    firewall-cmd --permanent --zone=public --remove-port=$PORT/udp -q
    firewall-cmd --reload -q
}

prompt() {
    # check firewalld installed
    firewalld_installed=`rpm -qa | grep firewalld | wc -l`
    if [ $firewalld_installed -ne 0 ]; then
        while true
        do
        echo ""
        stty erase '^H' && stty erase ^? && read -p "Please input port number: " port_num
        expr $port_num + 0 &>/dev/null
        if [ $? -eq 0 ]; then
            if [ $port_num -ge 1 ] && [ $port_num -le 65535 ]; then
                break
            else
                echo -e "\033[41;37m ERROR \033[0m Input error! Please input correct port numbers (1 - 65535)."
            fi
        else
            echo -e "\033[41;37m ERROR \033[0m Input error! Please input correct port numbers (1 - 65535)."
        fi
        done

        PORT="${port_num}"
        echo "[DEBUG] Port number is : ${PORT}"
    else
      echo -e "\033[41;37m WARNING \033[0m Firewalld looks like not installed, please manually set it if necessary."
    fi
}

start() {
    echo ""
    echo "Which one do you want to do?"
    echo "1. Add firewall port"
    echo "2. Remove firewall port"
    read -p "Input the number and press enter. (Press any other key to exit) " num

    case "$num" in
        [1] ) (prompt && add);;
        [2] ) (prompt && remove);;
        *) echo "Bye~~~";;
    esac
}

start