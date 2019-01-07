# docker-centos7-rutorrent

docker build -t centos7/rtorrent-flood .

docker run -d -t -v $(pwd)/downloads:/downloads -p8080:80 -p3000:3000 -p6970:6970 -p 56881:56881/udp -p 59995:59995 --name=rutorrent centos7/rtorrent-flood

docker exec -it rutorrent bash
