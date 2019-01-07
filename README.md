# docker-centos7-rutorrent

docker build -t centos7/rutorrent .

docker run -d -t -v $(pwd)/downloads:/downloads -p8080:80 --name=rutorrent centos7/rutorrent

docker run -d -t --name=rutorrent -e TZ=America/New_York -e USER=rutorrent -e USERUID=1001 -v $(pwd)/rtorrent-config:/config -v $(pwd)/downloads:/downloads -p 56881:56881/udp -p 59995:59995 -p8080:80 centos7/rutorrent

docker exec -it rutorrent bash
