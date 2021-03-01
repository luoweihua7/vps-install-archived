# Aria2 Install
执行以下命令根据提示选择安装
```bash
wget --no-check-certificate https://github.com/luoweihua7/vps-install/raw/master/aria2/aria2-install.sh && bash aria2-install.sh
```

### Aria2 安装程序包

配置存储在 `/usr/local/etc/aria2`<br>
下载文件存储在 `/data/downloads`<br>
AriaNG 网页存储在 `/data/www`<br>
aria2c 执行允许存储在 `/usr/local/bin`<br>
aria2 脚本存储在 `/etc/init.d`<br>
aria2c 任务前后置脚本在 `/usr/local/etc/aria2/script` 目录下<br>
同时会创建nginx的目录规则到 `/etc/nginx/conf.d/` 中

#### 更新BitTorrent的Tracker
选中任务，点击暂停，会触发暂停后置任务 `on-download-pause` ，在此后置任务中调用更新指令更新。暂停操作后一般网络正常的话可以5秒内更新成功。可以在配置中查看是否已更新。
详见：https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-on-download-pause

