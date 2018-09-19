# Aria2 Install

Aria2 安装程序包<br>
配置存储在 `/home/conf/aria2`<br>
下载文件存储在 `/home/downloads`<br>
AriaNG 网页存储在 `/home/www`<br>
aria2c 执行允许存储在 `/usr/local/bin`<br>
aria2 脚本存储在 `/etc/init.d`<br>

同时会创建nginx的目录规则到 `/etc/nginx/conf.d/` 中

执行以下命令根据提示选择安装
```bash
wget --no-check-certificate https://github.com/luoweihua7/vps-install/raw/master/aria2/aria2-install.sh && bash aria2-install.sh
```
