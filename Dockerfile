FROM alpine:3.3

ENV NGINX_VERSION 1.9.14
ENV PAGESPEED_VERSION 1.11.33.0-beta

RUN build_pkgs="build-base linux-headers openssl-dev pcre-dev wget zlib-dev subversion git patch bash gperf python apr-dev apr-util-dev libjpeg-turbo-dev icu-dev" && \
    runtime_pkgs="ca-certificates openssl pcre zlib" && \
    apk --no-cache --update add ${build_pkgs} ${runtime_pkgs} && \
    mkdir -p /tmp/src/mod_pagespeed/src && \
    cd /tmp/src && \
    wget https://sourceforge.net/projects/libpng/files/libpng12/1.2.56/libpng-1.2.56.tar.xz/download\?use_mirror\=tenet\&r\=https%3A%2F%2Fsourceforge.net%2Fprojects%2Flibpng%2Ffiles%2Flibpng12%2F1.2.56%2F\&use_mirror\=tenet\# -O libpng-1.2.56.tar.xz && \
    tar -Jxf libpng-1.2.56.tar.xz && \
    wget https://github.com/pagespeed/ngx_pagespeed/archive/v${PAGESPEED_VERSION}.tar.gz && \
    tar -zxvf v${PAGESPEED_VERSION}.tar.gz && \
    svn co https://src.chromium.org/svn/trunk/tools/depot_tools && \
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -zxvf nginx-${NGINX_VERSION}.tar.gz && \
    cd /tmp/src/mod_pagespeed && \
    git clone https://github.com/pagespeed/mod_pagespeed.git src && \
    cd /tmp/src/libpng-1.2.56 && \
    ./configure --prefix=/usr --disable-static && make && make install && \
    export PATH=$PATH:/tmp/src/depot_tools && \
    cd /tmp/src/mod_pagespeed && \
    export GYP_DEFINES="use_system_libs=1 _GLIBCXX_USE_CXX11_ABI=0 use_system_icu=1" && \
    gclient config https://github.com/pagespeed/mod_pagespeed.git --unmanaged --name=src && \
    cd src/ && \
    git checkout 1.11.33.0 && \
    gclient sync --force --jobs=1 && \
    cd /tmp/src/mod_pagespeed && \
    wget https://raw.githubusercontent.com/iler/alpine-nginx-pagespeed/master/automatic_makefile.patch && \
    wget https://raw.githubusercontent.com/iler/alpine-nginx-pagespeed/master/libpng_cflags.patch && \
    wget https://raw.githubusercontent.com/iler/alpine-nginx-pagespeed/master/pthread_nonrecursive_np.patch && \
    wget https://raw.githubusercontent.com/iler/alpine-nginx-pagespeed/master/rename_c_symbols.patch && \
    wget https://raw.githubusercontent.com/iler/alpine-nginx-pagespeed/master/stack_trace_posix.patch && \
    patch -p1 -i automatic_makefile.patch && \
    patch -p1 -i libpng_cflags.patch && \
    patch -p1 -i pthread_nonrecursive_np.patch && \
    patch -p1 -i rename_c_symbols.patch && \
    patch -p1 -i stack_trace_posix.patch && \
    cd src/ && \
    make BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I/tmp/src/libpng-1.2.56 \
    -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 \
    -I/tmp/src/libpng-1.2.56 -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
    cd /tmp/src/mod_pagespeed/src/pagespeed/automatic && \
    make all BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I/tmp/src/libpng-1.2.56 \
    -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 \
    -I/tmp/src/libpng-1.2.56 -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
    cd /tmp/src/nginx-${NGINX_VERSION} && \
    MOD_PAGESPEED_DIR="/tmp/src/mod_pagespeed/src" ./configure \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-file-aio \
        --with-http_v2_module \
        --without-http_autoindex_module \
        --without-http_browser_module \
        --without-http_geo_module \
        --without-http_map_module \
        --without-http_memcached_module \
        --without-http_userid_module \
        --without-mail_pop3_module \
        --without-mail_imap_module \
        --without-mail_smtp_module \
        --without-http_split_clients_module \
        --without-http_uwsgi_module \
        --without-http_scgi_module \
        --without-http_referer_module \
        --without-http_upstream_ip_hash_module \
        --prefix=/etc/nginx \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --sbin-path=/usr/local/sbin/nginx \
        --add-module=/tmp/src/ngx_pagespeed-${NGINX_VERSION}/ && \
    make && \
    make install && \
    apk del ${build_pkgs} && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*

VOLUME ["/var/log/nginx"]

WORKDIR /etc/nginx

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]