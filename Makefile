all: help

help:
	@echo ""
	@echo "-- Help Menu"
	@echo "   1. make build       - build the docker container"

build: builddocker beep

runold: rundocker beep

run: mysql tryout beep

runupstream: mysql upstream beep

rundocker:
	@docker run --name=dockericinga2 \
	-v ~/.ssh:/tmp/.ssh \
	--cidfile="cid" \
	-v ~/.gitconfig:/root/.gitconfig \
	-v /var/run/docker.sock:/run/docker.sock \
	-v $(shell which docker):/bin/docker \
	-t dockericinga2

builddocker:
	/usr/bin/time -v docker build -t dockericinga2 .

beep:
	@echo "beep"
	@aplay /usr/share/sounds/alsa/Front_Center.wav

setup:
	docker run -it --rm --link mysql:mysql -t dockericinga2 setup

pull:
	docker pull joshuacox/docker-icinga2

upstream:
	docker run --name=joshuacoxdockericinga2 \
	-P \
	--cidfile="cid" \
	-d \
	--link mysql:mysql \
	-e "ICINGA_DB_PASSWORD=REPLACEMEDB" \
	-e "ICINGAWEB_DB_PASSWORD=REPLACEMEWEBDB" \
	-v $(shell which docker):/bin/docker \
	-t joshuacox/docker-icinga2

tryout:
	docker run --name=dockericinga2 \
	-P \
	--cidfile="cid" \
	-d \
	--link mysql:mysql \
	-e "ICINGA_DB_PASSWORD=REPLACEMEDB" \
	-e "ICINGAWEB_DB_PASSWORD=REPLACEMEWEBDB" \
	-v $(shell which docker):/bin/docker \
	-t dockericinga2

killmysql:
	@docker kill `cat mysql`

kill:
	@docker kill `cat cid`

rm-name:
	@docker rm name

rmmysql-image:
	@docker rm `cat mysql`
	@rm mysql

rm-image:
	@docker rm `cat cid`
	@rm cid

cleanfiles:
	rm name
	rm repo
	rm proxy
	rm proxyport

rm: kill rm-image

rmmysql: killmysql rmmysql-image

clean: cleanfiles rm

enter:
	docker exec -i -t `cat cid` /bin/bash

mysql:
	docker run --name mysql \
	--cidfile="mysql" \
	-e MYSQL_ROOT_PASSWORD=insecurepassword123 \
	-d mysql
