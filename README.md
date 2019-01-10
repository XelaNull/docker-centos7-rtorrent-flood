# Dockerfile for CentOS 7.6 + PHP 7.2 + rTorrent + Flood + Pyrocore

The combination provided by this project is one of the better seedbox configurations. The Flood UI is modern and really smooth looking. Backing it up is rtorrent, with PEX & DHT disabled by default. If you wish to enable them, the option is right inside the single Dockerfile. I'm not a fan of multiple files and prefer to keep things in a single Dockerfile.

The goal of this project is to provide a single Dockerfile that will create a Docker container that is comprised of:

- CentOS 7
- Supervisor
- Syslog-NG
- Cron
- PHP 7.2
- rTorrent
- Flood
- Pyrocore

**Packages Installed**

- rar / unrar
- unrarall + cksfv
- ffmpeg
- unzip
- sudo
- nodejs 11

The Pyrocore support above is really key as it provides flexible control over how long to seed or up to what ratio.

**To Get:**

```
git clone git@github.com:XelaNull/docker-centos7-rtorrent-flood.git && cd docker-centos7-rtorrent-flood
```

**To Build:**

```
docker build -t centos7/rtorrent-flood .
```

**To Run:**

```
docker run -d -t -p8080:80 -p3000:3000 --name=rtorrent-flood centos7/rtorrent-flood
```

**To Enter:**

```
docker exec -it rtorrent-flood bash
```

**To Access Flood:**

```
https://YOURIP:3000
```

**To Access Torrent Downloads:**

```
http://YOURIP:8080/complete
```
