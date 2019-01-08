# Create CentOS7 Minimal Container
FROM centos:7

#Currently works with a blank root MariaDB password (BAD IDEA)
ENV TIMEZONE="America/New_York"

# First install EPEL & Webtatic REPOs as they are needed for some of the initial packages
RUN yum -y install epel-release wget vim-enhanced net-tools perl make gcc-c++ rsync && \
    nc cronie openssh sudo mlocate git logrotate screen

# Install Webtatic YUM REPO, to provide PHP7
RUN wget https://mirror.webtatic.com/yum/el7/webtatic-release.rpm && yum -y localinstall webtatic-release.rpm && \
    yum -y install supervisor syslog-ng mod_php72w php72w-opcache php72w-cli rtorrent unzip mediainfo httpd

# Install rar & unrar
RUN cd /root && wget https://www.rarlab.com/rar/rarlinux-x64-5.5.0.tar.gz && \
    tar -zxf rarlinux-x64-5.5.0.tar.gz && cd rar && cp rar unrar /usr/local/bin/

#ffmpeg
RUN wget http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm && \
    yum -y localinstall nux-dextop-release-0-5.el7.nux.noarch.rpm && yum -y install ffmpeg ffmpeg-devel

# rTorrent
RUN adduser rtorrent && \
    { \
    echo 'directory = /var/www/html/downloads'; \
    echo 'session = /srv/torrent/.session'; \
    echo 'port_range = 50000-50000'; \
    echo 'port_random = no'; \
    echo 'check_hash = yes'; \
    echo 'dht = disable'; \
    echo 'dht_port = 6881'; \
    echo 'peer_exchange = no'; \
    echo 'use_udp_trackers = yes'; \
    echo 'encryption = allow_incoming,try_outgoing,enable_retry'; \
    echo 'scgi_port = 127.0.0.1:5000'; \
    } | tee /home/rtorrent/.rtorrent.rc && chown rtorrent:rtorrent /home/rtorrent/.rtorrent.rc && \
    mkdir /srv/torrent && mkdir /srv/torrent/.session && \
    chmod 775 -R /srv/torrent && chown rtorrent:rtorrent -R /srv/torrent && \
    mkdir /var/www/html/downloads && chown apache:rtorrent /var/www/html/downloads && chmod 775 /var/www/html/downloads
    
# flood
RUN curl -sL https://rpm.nodesource.com/setup_8.x | bash - && yum install -y nodejs && \
    cd /srv/torrent && git clone https://github.com/jfurrow/flood.git && \
    cd flood && cp config.template.js config.js && \
    sed -i "s|floodServerHost: '127.0.0.1'|floodServerHost: '0.0.0.0'|g" config.js && \
    npm install && npm install -g node-gyp && npm run build && \
    adduser flood && chown -R flood:flood /srv/torrent/flood/ && \
    { \
    echo '#!/bin/bash'; \
    echo 'cd /srv/torrent/flood/ && /usr/bin/npm start && while true; do sleep 60; done'; \
    } | tee /start_flood.sh
    
# Create supervisord.conf file
RUN { \
    echo '#!/bin/bash'; \
    echo 'echo "[program:$1]";'; echo 'echo "process_name=$1";'; \
    echo 'echo "autostart=true";'; echo 'echo "autorestart=false";'; \
    echo 'echo "directory=/";'; echo 'echo "command=$2";'; \
    echo 'echo "startsecs=3";'; echo 'echo "priority=1";'; echo 'echo "";'; \
  } | tee /gen_sup.sh && chmod a+x /*.sh && \
  { echo '[supervisord]';echo 'nodaemon=true';echo 'user=root';echo 'logfile=/var/log/supervisord'; echo; } | tee /etc/supervisord.conf && \  
    /gen_sup.sh syslog-ng "/usr/sbin/syslog-ng -F" >> /etc/supervisord.conf && \
    /gen_sup.sh crond "/usr/sbin/crond -n" >> /etc/supervisord.conf && \
    /gen_sup.sh rtorrent "sudo -u rtorrent /usr/bin/rtorrent" >> /etc/supervisord.conf && \
    /gen_sup.sh flood "sudo -u flood /start_flood.sh" >> /etc/supervisord.conf
    
# Ensure all packages are up-to-date, then fully clean out all cache
RUN yum -y update && yum clean all && rm -rf /tmp/* && rm -rf /var/tmp/*

# Set to start the supervisor daemon on bootup
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
