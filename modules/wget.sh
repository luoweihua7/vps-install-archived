update_wget() {
    yum install -y openssl-devel openssl
    #wget_ver="wget-1.20.3"
    #wget https://ftp.gnu.org/gnu/wget/${wget_ver}.tar.gz
    # tar xvf ${wget_ver}.tar.gz
    # cd ${wget_ver}

    wget http://mirrors.ustc.edu.cn/gnu/wget/wget-latest.tar.gz
    mkdir /tmp/wget-latest
    tar xvf wget-latest.tar.gz -C /tmp/wget-latest --strip-components 1
    cd /tmp/wget-latest
    ./configure --prefix=/usr --sysconfdir=/etc --with-ssl=openssl
    make && make install
    cd ~/
    rm -rf /tmp/wget-latest
}