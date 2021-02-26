#!/usr/bin/env bash

ARIA2_CONF="/usr/local/etc/aria2/aria2.conf"
RPC_ADDRESS="http://localhost:6800/jsonrpc"

RANDSTR(){
    index=0
    strRandomPass=""
    for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
    for i in {1..16}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
    echo $strRandomPass
}

DATE_TIME() {
  date +"%m/%d %H:%M:%S"
}

GET_TRACKERS() {
  echo && echo -e "$(DATE_TIME) Start get BT trackers ..."
  DOWNLOADER="curl -fsSL --connect-timeout 3 --max-time 3 --retry 2"
  TRACKER=$(
    ${DOWNLOADER} https://trackerslist.com/all_aria2.txt ||
        ${DOWNLOADER} https://cdn.jsdelivr.net/gh/XIU2/TrackersListCollection@master/all_aria2.txt ||
        ${DOWNLOADER} https://trackers.p3terx.com/all_aria2.txt
    )
  [[ -z "${TRACKER}" ]] && {
    echo
    echo -e "$(DATE_TIME) Unable to get trackers, network failure or invalid links." && exit 1
  }
}

ADD_TRACKERS() {
    echo -e "$(DATE_TIME) Adding BT trackers to Aria2 configuration file ${ARIA2_CONF} ..."
    if [ ! -f ${ARIA2_CONF} ]; then
        echo -e "$(DATE_TIME) '${ARIA2_CONF}' does not exist."
        exit 1
    else
        # 更新到conf配置文件
        [ -z $(grep "bt-tracker=" ${ARIA2_CONF}) ] && echo "bt-tracker=" >>${ARIA2_CONF}
        sed -i "s@^\(bt-tracker=\).*@\1${TRACKER}@" ${ARIA2_CONF} && echo -e "$(DATE_TIME) BT trackers successfully added to Aria2 configuration file !"

        # 通过接口更新当前服务
        REQID=`RANDSTR`
        if [ -z $(grep "rpc-secret=" ${ARIA2_CONF}) ]; then
          RPC_PAYLOAD='{"jsonrpc":"2.0","method":"aria2.changeGlobalOption","id":"'${REQID}'","params":[{"bt-tracker":"'${TRACKER}'"}]}'
        else
          # 非得在secret配置后面加注释的话，就不管了
          RPC_SECRET=`grep "rpc-secret=" ${ARIA2_CONF} | awk -F "=" '{print $2}'`
          RPC_PAYLOAD='{"jsonrpc":"2.0","method":"aria2.changeGlobalOption","id":"'${REQID}'","params":["token:'${RPC_SECRET}'",{"bt-tracker":"'${TRACKER}'"}]}'
        fi
        UPDATE_RESULT=`curl "${RPC_ADDRESS}" -fsSd "${RPC_PAYLOAD}" || curl "https://${RPC_ADDRESS}" -kfsSd "${RPC_PAYLOAD}"`
        echo -e "$(DATE_TIME) ${UPDATE_RESULT}"
        echo -e "$(DATE_TIME) BT trackers updated!"
    fi
}

GET_TRACKERS
ADD_TRACKERS