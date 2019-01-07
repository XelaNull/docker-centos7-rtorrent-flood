# Create CentOS7 Minimal Container
FROM centos:7

#Currently works with a blank root MariaDB password (BAD IDEA)
ENV TIMEZONE="America/New_York"

# First install EPEL & Webtatic REPOs as they are needed for some of the initial packages
RUN yum -y install epel-release yum-utils

# Install newest stable MariaDB: 10.3 
#RUN { echo "[mariadb]"; echo "name = MariaDB"; echo "baseurl = http://yum.mariadb.org/10.3/centos7-amd64"; \
#    echo "gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB"; BTW Lecho "gpgcheck=1"; \
#    } | tee /etc/yum.repos.d/MariaDB-10.3.repo && yum -y install MariaDB-server MariaDB-client  
# Create MySQL Start Script
#RUN { echo "#!/bin/bash"; \
#    echo "[[ \`pidof /usr/sbin/mysqld\` == \"\" ]] && /usr/bin/mysqld_safe &"; \
#    echo "export SQL_TO_LOAD='/mysql_load_on_first_boot.sql';"; \
#    echo "while true; do"; \
#    echo "if [[ ! -d \"/var/lib/mysql/${DBNAME}\" ]]; then sleep 5 && /usr/bin/mysql -u root --password='' < \$SQL_TO_LOAD && mv \$SQL_TO_LOAD /torrentflux-b4rt_custom.sql && chown apache /var/www/html/downloads; fi"; \
#    echo "sleep 10;"; \
#    echo "done"; \
#    } | tee /start-mysqld.sh && chmod a+x /start-mysqld.sh 

# Install all other YUM-based packages
RUN yum -y install bash wget supervisor vim-enhanced net-tools perl make gcc-c++ \
    rsync nc cronie openssh sudo syslog-ng mlocate git logrotate

# Install rar & unrar
RUN cd /root && wget https://www.rarlab.com/rar/rarlinux-x64-5.5.0.tar.gz && tar -zxf rarlinux-x64-5.5.0.tar.gz && cd rar && cp rar unrar /usr/local/bin/

# Install Webtatic YUM REPO, to provide PHP7
RUN rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm && \
    yum -y install mod_php72w php72w-opcache php72w-cli php72w-mysqli httpd

RUN yum -y install rtorrent httpd unzip screen
# mediainfo ffmpeg

RUN git clone https://github.com/Novik/ruTorrent.git && chown -R apache:apache /ruTorrent/share/torrents && \
    chown -R apache:apache /ruTorrent/share/settings

RUN adduser rtorrent
ADD rctorrent.rc /home/rtorrent/.rtorrent.rc
RUN chown rtorrent:rtorrent /home/rtorrent/.rtorrent.rc && \
    mkdir /srv/torrent && mkdir /srv/torrent/downloads && mkdir /srv/torrent/.session && \
    chmod 775 -R /srv/torrent && chown rtorrent:rtorrent -R /srv/torrent && \
    chown rtorrent:rtorrent /home/rtorrent/.rtorrent.rc


# flood
RUN yum install gcc-c++ make curl git -y && curl -sL https://rpm.nodesource.com/setup_8.x | bash -
RUN yum install -y nodejs && \
    cd /srv/torrent && git clone https://github.com/jfurrow/flood.git && \
    cd flood && cp config.template.js config.js && \
    sed -i "s|floodServerHost: '127.0.0.1'|floodServerHost: '0.0.0.0'|g" config.js && \
    npm install && npm install -g node-gyp && npm run build && \
    adduser flood && chown -R flood:flood /srv/torrent/flood/

ADD start_rtorrent.sh /start_rtorrent.sh
ADD start_flood.sh /start_flood.sh

# Create supervisord.conf file
RUN { \
    echo '#!/bin/bash'; \
    echo 'echo "[program:$1]";'; \
    echo 'echo "process_name=$1";'; \
    echo 'echo "autostart=true";'; \
    echo 'echo "autorestart=false";'; \
    echo 'echo "directory=/";'; \
    echo 'echo "command=$2";'; \
    echo 'echo "startsecs=3";'; \
    echo 'echo "priority=1";'; \
    echo 'echo "";'; \
  } | tee /gen_sup.sh && chmod a+x /*.sh && \
  { echo '[supervisord]';echo 'nodaemon=true';echo 'user=root';echo 'logfile=/var/log/supervisord'; echo; } | tee /etc/supervisord.conf && \  
    /gen_sup.sh syslog-ng "/usr/sbin/syslog-ng -F" >> /etc/supervisord.conf && \
    /gen_sup.sh crond "/usr/sbin/crond -n" >> /etc/supervisord.conf && \
    /gen_sup.sh rtorrent "/start_rtorrent.sh" >> /etc/supervisord.conf && \
    /gen_sup.sh flood "/start_flood.sh" >> /etc/supervisord.conf
    
# Ensure all packages are up-to-date, then fully clean out all cache
RUN yum -y update && yum clean all && rm -rf /tmp/* && rm -rf /var/tmp/*

# Define the downloads directory as an externally mounted volume
VOLUME ["/config","/downloads"]
# Set to start the supervisor daemon on bootup
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
