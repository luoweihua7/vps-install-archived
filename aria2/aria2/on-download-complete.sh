#!/bin/sh

filepath=$3
downloadpath='/home/downloads/'

# 获取文件名
file=${filepath##*/}

curl -X POST -H "Content-Type: application/json" -d '{"value1":"下载完成","value2":"文件'"${file}"'下载已完成","value3":"https://i.loli.net/2019/06/03/5cf4e4a60603411210.png"}' https://maker.ifttt.com/trigger/aria2/with/key/IFTTT_KEY
