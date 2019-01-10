# Create CentOS7 Minimal Container
FROM centos:7

#Currently works with a blank root MariaDB password (BAD IDEA)
ENV TIMEZONE="America/New_York"
ENV DIR_INCOMING="/var/www/html/incomplete"
ENV DIR_OUTGOING="/var/www/html/outgoing"
ENV RTORRENT_PORT="5000"
ENV DELETE_AFTER_HOURS="75"
ENV DELETE_AFTER_RATIO="1.0"
ENV DELETE_AFTER_RATIO_REQ_SEEDTIME="12"
ENV DHT_ENABLE="disable"
ENV USE_PEX="no"

# First install EPEL & initial packages
RUN yum -y install epel-release wget vim-enhanced net-tools perl make gcc-c++ rsync && \
    yum -y install nc cronie openssh sudo mlocate git logrotate screen
    
# Install Webtatic YUM REPO, to provide PHP7
RUN wget https://mirror.webtatic.com/yum/el7/webtatic-release.rpm && yum -y localinstall webtatic-release.rpm && \
    yum -y install supervisor syslog-ng mod_php72w php72w-opcache php72w-cli rtorrent unzip mediainfo httpd && \
    rm -rf /etc/httpd/conf.d/welcome.conf && { \
    echo '<?php'; \
    echo "\$display = Array ('img','mp4','avi','mkv','m2ts','wmv','iso','divx','mpg','m4v');"; \
    echo "foreach(new RecursiveIteratorIterator(new RecursiveDirectoryIterator(basename(${DIR_OUTGOING}))) as \$file)"; \
    echo "{ if(basename($file)=='..' || basename($file)=='.') continue; if (in_array(strtolower(array_pop(explode('.', \$file))), \$display))"; \
    echo 'echo "http://$_SERVER[HTTP_HOST]/". $file . "\n<br/>"; }'; \
    echo '?>'; } | tee /var/www/html/scan.php && touch /var/www/html/index.php && \
    sed -i 's|system();|unix-stream("/dev/log");|g' /etc/syslog-ng/syslog-ng.conf

# Install rar, unrar, and unrarall
RUN cd /root && wget https://www.rarlab.com/rar/rarlinux-x64-5.5.0.tar.gz && \
    tar -zxf rarlinux-x64-5.5.0.tar.gz && cd rar && cp rar unrar /usr/local/bin/ && \
    git clone http://github.com/arfoll/unrarall.git unrarall/ && cd unrarall && \
    chmod a+x unrarall && cp unrarall /usr/local/sbin/ 

#ffmpeg
RUN wget http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm && \
    yum -y localinstall nux-dextop-release-0-5.el7.nux.noarch.rpm && yum -y install ffmpeg ffmpeg-devel

# rTorrent
RUN adduser rtorrent && { \
    echo "directory = ${DIR_INCOMING}"; \
    echo 'session = /srv/torrent/.session'; \
    echo 'port_range = 50000-50000'; \
    echo 'port_random = no'; \
    echo 'check_hash = yes'; \
    echo "dht = ${DHT_ENABLE}"; \
    echo 'dht_port = 6881'; \
    echo "peer_exchange = ${USE_PEX}"; \
    echo 'use_udp_trackers = yes'; \
    echo 'encryption = allow_incoming,try_outgoing,enable_retry'; \
    echo "scgi_port = 127.0.0.1:${RTORRENT_PORT}"; \
    echo 'ratio.enable='; \
    echo "method.insert = d.get_finished_dir, simple, \"cat=${DIR_OUTGOING}/,\$d.custom1=\""; \
    echo 'method.insert = d.get_data_full_path, simple, "branch=((d.is_multi_file)),((cat,(d.directory))),((cat,(d.directory),/,(d.name)))"'; \
    echo 'method.insert = d.move_to_complete, simple, "execute=mkdir,-p,$argument.1=; execute=cp,-rp,$argument.0=,$argument.1=; d.stop=; d.directory.set=$argument.1=; d.start=;d.save_full_session=; execute=rm, -r, $argument.0="'; \
    echo 'method.set_key = event.download.finished,move_complete,"d.move_to_complete=$d.get_data_full_path=,$d.get_finished_dir="'; \
    } | tee /home/rtorrent/.rtorrent.rc && chown rtorrent:rtorrent /home/rtorrent/.rtorrent.rc && \
    mkdir /srv/torrent && mkdir /srv/torrent/.session && \
    chmod 775 -R /srv/torrent && chown rtorrent:rtorrent -R /srv/torrent && \
    mkdir ${DIR_INCOMING} && chown apache:rtorrent ${DIR_INCOMING} -R && chmod 775 ${DIR_INCOMING} && \
    mkdir ${DIR_OUTGOING} && chown apache:rtorrent ${DIR_OUTGOING} -R && chmod 775 ${DIR_OUTGOING}

# Install Pyrocore, to get rtcontrol to stop torrents from seeding after xxx days
RUN cd /home/rtorrent && mkdir -p bin pyroscope && git clone "https://github.com/pyroscope/pyrocore.git" pyroscope && \
chown rtorrent /home/rtorrent -R && sudo -u rtorrent /home/rtorrent/pyroscope/update-to-head.sh 

# flood
 RUN curl -sL https://rpm.nodesource.com/setup_11.x | bash - && yum install -y nodejs && \
    cd /srv/torrent && git clone https://github.com/jfurrow/flood.git && \
    cd flood && cp config.template.js config.js && \
    sed -i "s|floodServerHost: '127.0.0.1'|floodServerHost: '0.0.0.0'|g" config.js && \
    npm install && npm install -g node-gyp && npm run build && \
    adduser flood && chown -R flood:flood /srv/torrent/flood/ && \
    { \
    echo '#!/bin/bash'; \
    echo 'cd /srv/torrent/flood/ && /usr/bin/npm start && while true; do sleep 60; done'; \
    } | tee /start_flood.sh
    
RUN { \
    echo '#!/bin/bash'; \
    echo 'sleep 30 && /usr/sbin/crond -n'; \
    } | tee /start_crond.sh    
    
# Create supervisord.conf file
RUN { echo '#!/bin/bash'; \
    echo 'echo "[program:$1]";'; echo 'echo "process_name=$1";'; \
    echo 'echo "autostart=true";'; echo 'echo "autorestart=false";'; \
    echo 'echo "directory=/";'; echo 'echo "command=$2";'; \
    echo 'echo "startsecs=3";'; echo 'echo "priority=1";'; echo 'echo "";'; \
  } | tee /gen_sup.sh && chmod a+x /*.sh && \
  { echo '[supervisord]';echo 'nodaemon=true';echo 'user=root';echo 'logfile=/var/log/supervisord'; } | tee /etc/supervisord.conf && \  
    /gen_sup.sh syslog-ng "/usr/sbin/syslog-ng --no-caps -F -p /var/run/syslogd.pid" >> /etc/supervisord.conf && \
    /gen_sup.sh rtorrent "sudo -u rtorrent /usr/bin/rtorrent" >> /etc/supervisord.conf && \
    /gen_sup.sh flood "sudo -u flood /start_flood.sh" >> /etc/supervisord.conf && \
    /gen_sup.sh httpd "/usr/sbin/apachectl -D FOREGROUND" >> /etc/supervisord.conf && \
    /gen_sup.sh crond "/start_crond.sh" >> /etc/supervisord.conf
    
RUN echo "*/1 * * * * rtorrent /home/rtorrent/bin/rtcontrol --cron seedtime=+${DELETE_AFTER_HOURS}h is_complete=y [ NOT up=+0 ] --cull --yes" > /etc/cron.d/rtorrent && \
    echo "*/1 * * * * rtorrent /home/rtorrent/bin/rtcontrol --cron seedtime=+${DELETE_AFTER_RATIO_REQ_SEEDTIME}h ratio=+${DELETE_AFTER_RATIO} is_complete=y [ NOT up=+0 ] --cull --yes" >> /etc/cron.d/rtorrent
    
# Ensure all packages are up-to-date, then fully clean out all cache
RUN yum -y update && yum clean all && rm -rf /tmp/* && rm -rf /var/tmp/*

# Set to start the supervisor daemon on bootup
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
