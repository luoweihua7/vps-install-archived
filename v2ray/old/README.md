# V2Ray 一键安装配置

自动安装V2Ray，并配置 `WebSocket+TLS+Web`。<br>
目前为止 `CentOS 7.4` 以上测试通过

# 安装步骤

### 第一步
准备好自己的 `二级域名`，例如 sub.example.com（后面的TLS需要用到此域名），目前仅支持阿里云（因为自己的在阿里云）

### 第二步
点击[这里](https://ak-console.aliyun.com)打开页面，准备好阿里云的 Access Key，包括 `AccessKey ID` 和 `Access Key Secret`。<br>
因为自己使用下来，发现通过 `acme.sh` 配置时可以快速搞定减少很多问题，增加配置成功率

### 第三步
在VPS上安装好Nginx，配置TLS二级域名方便
```
rpm -ivh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
yum install nginx -y
systemctl enable nginx.service
```

### 第四步
开始安装 V2Ray（WebSocket+TLS+Web）服务
```
wget --no-check-certificate https://raw.githubusercontent.com/luoweihua7/vps-install/master/v2ray/v2ray.sh
sh v2ray.sh
```
按照流程配置即可。

# 实现过程

1. 自动强制安装 (--force) [V2Ray-Core](https://github.com/v2ray/v2ray-core)
2. 使用教程 [toutyrater 的白话文配置 WebSocket+TLS+Web](https://toutyrater.github.io/advanced/wss_and_web.html) 一样的配置信息
3. 使用 [acme.sh](https://acme.sh) 和 阿里云Access Key获取并设置子域名的SSL证书
3. 替换输入的内容：`子域名`, 并使用随机生成的 V2Ray `端口`, `UUID` 和 TLS 的 `path`，以及固定的 Websocket 和 SSL 端口 `443` 来配置V2Ray的 `config.json` 文件
4. 根据配置生成 ClashX，Shadowrocket，Quantumult 的配置