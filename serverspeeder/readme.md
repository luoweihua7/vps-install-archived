# ServerSpeeder
Change kernel
```bash
wget http://ftp.scientificlinux.org/linux/scientific/6.6/x86_64/updates/security/kernel-2.6.32-504.3.3.el6.x86_64.rpm
rpm -ivh kernel-2.6.32-504.3.3.el6.x86_64.rpm --force
reboot now
```
<br>
Install
```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/91yun/serverspeeder/master/serverspeeder-all.sh && bash serverspeeder-all.sh
```
