# shadowsocks-libev
### CentOS
本脚本在CentOS 6、7下使用过
其他环境应该不可用
```bash
wget --no-check-certificate https://github.com/luoweihua7/vps-install/raw/master/shadowsocks/shadowsocks-libev.sh
sh shadowsocks-libev.sh
```
按照提示操作即可。
如需添加多个用户，可重复执行命令按照提示添加，会自动创建多个配置。
通过 `ps aux | grep ss-server` 搜索可以看到对应的进程
<br>
<br>

# shadowsocks over kcptun
```bash
wget --no-check-certificate https://github.com/luoweihua7/vps-install/raw/master/shadowsocks/shadowsocks-over-kcp.sh
sh shadowsocks-over-kcp.sh
```
根据自己测试，kcp会定时断，应该是被QoS了。
