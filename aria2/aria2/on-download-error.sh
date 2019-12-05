#!/bin/sh

filepath=$3
downloadpath='/home/downloads/'

# 获取文件名
file=${filepath##*/}

curl -X POST -H "Content-Type: application/json" -d '{"value1":"下载失败","value2":"文件'"${file}"'下载出错，请重试","value3":"https://i.loli.net/2019/06/03/5cf4e4a60603411210.png"}' https://maker.ifttt.com/trigger/aria2/with/key/IFTTT_KEY
