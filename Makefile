.PHONY: all help build run builddocker rundocker kill rm-image rm clean enter logs

all: help

help:
	@echo ""
	@echo "-- Help Menu"
	@echo ""  This is merely a base image for usage read the README file
	@echo ""   1. make run       - build and run docker container
	@echo ""   2. make build     - build docker container
	@echo ""   3. make clean     - kill and remove docker container
	@echo ""   4. make enter     - execute an interactive bash in docker container
	@echo ""   3. make logs      - follow the logs of docker container

build: NAME TAG builddocker

# run a plain container
run: rm build rundocker

# run a  container that requires mysql temporarily
temp: MYSQL_PASS rm build mysqltemp runmysqltemp

# run a  container that requires mysql in production with persistent data
# HINT: use the grabmysqldatadir recipe to grab the data directory automatically from the above runmysqltemp
prod: DATADIR MYSQL_PASS rm build mysqlcid runprod

## useful hints
## specifiy ports
#-p 44180:80 \
#-p 27005:27005/udp \
## link another container
#--link some-mysql:mysql \
## assign environmant variables
#--env STEAM_USERNAME=`cat steam_username` \
#--env STEAM_PASSWORD=`cat steam_password` \

# change uid in the container for easy dev work
# first you need to determin your user:
# $(eval UID := $(shell id -u))
# then you need to insert this as a env var:
# -e "DOCKER_UID=$(UID)" \
# then look at chguid.sh for an example of 
# what needs to be run in the live container upon startup

rundocker:
	$(eval DOCKER_HOST := $(shell cat DOCKER_HOST))
	$(eval DOCKER_OPTS := $(shell cat DOCKER_OPTS))
	$(eval NODE_RESTRICTION := $(shell cat NODE_RESTRICTION))
	$(eval TMP := $(shell mktemp -d --suffix=DOCKERTMP))
	$(eval NAME := $(shell cat NAME))
	$(eval MY_NET := $(shell cat MY_NET))
	$(eval TAG := $(shell cat TAG))
	chmod 777 $(TMP)
	docker \
	$(DOCKER_HOST) \
	run --name=$(NAME) \
	$(NODE_RESTRICTION) \
	$(DOCKER_OPTS) \
	--cidfile="cid" \
	-v $(TMP):/tmp \
	--net=$(MY_NET) \
	-d \
	-P \
	-v /var/run/docker.sock:/run/docker.sock \
	-v $(shell which docker):/bin/docker \
	-t $(TAG)

runmysqltemp:
	$(eval DOCKER_OPTS := $(shell cat DOCKER_OPTS))
	$(eval NODE_RESTRICTION := $(shell cat NODE_RESTRICTION))
	$(eval TMP := $(shell mktemp -d --suffix=DOCKERTMP))
	$(eval NAME := $(shell cat NAME))
	$(eval MY_NET := $(shell cat MY_NET))
	$(eval TAG := $(shell cat TAG))
	chmod 777 $(TMP)
	docker \
	$(DOCKER_HOST) \
	run --name=$(NAME) \
	$(NODE_RESTRICTION) \
	$(DOCKER_OPTS) \
	--cidfile="cid" \
	-v $(TMP):/tmp \
	--net=$(MY_NET) \
	-d \
	-P \
	--link `cat NAME`-mysqltemp:mysql \
	-v /var/run/docker.sock:/run/docker.sock \
	-v $(shell which docker):/bin/docker \
	-t $(TAG)

runprod:
	$(eval DOCKER_OPTS := $(shell cat DOCKER_OPTS))
	$(eval NODE_RESTRICTION := $(shell cat NODE_RESTRICTION))
	$(eval DATADIR := $(shell cat DATADIR))
	$(eval TMP := $(shell mktemp -d --suffix=DOCKERTMP))
	$(eval NAME := $(shell cat NAME))
	$(eval MY_NET := $(shell cat MY_NET))
	$(eval TAG := $(shell cat TAG))
	chmod 777 $(TMP)
	docker \
	$(DOCKER_HOST) \
	run --name=$(NAME) \
	$(NODE_RESTRICTION) \
	$(DOCKER_OPTS) \
	--cidfile="cid" \
	-v $(TMP):/tmp \
	--net=$(MY_NET) \
	-d \
	-p 4080:80 \
	-p 4443:443 \
	-p 4665:5665 \
	--link `cat NAME`-mysql:mysql \
	-v /var/run/docker.sock:/run/docker.sock \
	-v $(DATADIR)/lib/icinga2:/var/lib/icinga2 \
	-v $(DATADIR)/etc/icinga:/etc/icinga \
	-v $(DATADIR)/etc/icinga2:/etc/icinga2 \
	-v $(DATADIR)/etc/icinga2-classicui:/etc/icinga2-classicui \
	-v $(DATADIR)/etc/icingaweb2:/etc/icingaweb2 \
	-v $(shell which docker):/bin/docker \
	-t $(TAG)

builddocker:
	/usr/bin/time -v docker build -t `cat TAG` .

kill:
	-@docker kill `cat cid`

rm-image:
	-@docker rm `cat cid`
	-@rm cid

rm: kill rm-image

clean: rm

enter:
	docker exec -i -t `cat cid` /bin/bash

logs:
	docker logs -f `cat cid`

NAME:
	@while [ -z "$$NAME" ]; do \
		read -r -p "Enter the name you wish to associate with this container [NAME]: " NAME; echo "$$NAME">>NAME; cat NAME; \
	done ;

TAG:
	@while [ -z "$$TAG" ]; do \
		read -r -p "Enter the tag you wish to associate with this container [TAG]: " TAG; echo "$$TAG">>TAG; cat TAG; \
	done ;

# MYSQL additions
# use these to generate a mysql container that may or may not be persistent

mysqlcid:
	$(eval DOCKER_OPTS := $(shell cat DOCKER_OPTS))
	$(eval NODE_RESTRICTION := $(shell cat NODE_RESTRICTION))
	$(eval DATADIR := $(shell cat DATADIR))
	$(eval NAME := $(shell cat NAME))
	$(eval MY_NET := $(shell cat MY_NET))
	docker \
	$(DOCKER_HOST) \
	run \
	--name `cat NAME`-mysql \
	$(NODE_RESTRICTION) \
	$(DOCKER_OPTS) \
	--cidfile="mysqlcid" \
	-e MYSQL_ROOT_PASSWORD=`cat MYSQL_PASS` \
	--net=$(MY_NET) \
	-d \
	-v $(DATADIR)/mysql:/var/lib/mysql \
	local-mysql

rmmysql: mysqlcid-rmkill

mysqlcid-rmkill:
	-@docker kill `cat mysqlcid`
	-@docker rm `cat mysqlcid`
	-@rm mysqlcid

# This one is ephemeral and will not persist data
mysqltemp:
	$(eval DOCKER_OPTS := $(shell cat DOCKER_OPTS))
	$(eval NODE_RESTRICTION := $(shell cat NODE_RESTRICTION))
	$(eval NAME := $(shell cat NAME))
	$(eval MY_NET := $(shell cat MY_NET))
	docker \
	$(DOCKER_HOST) \
	run \
	--name `cat NAME`-mysql \
	$(NODE_RESTRICTION) \
	$(DOCKER_OPTS) \
	--cidfile="mysqltemp" \
	--name `cat NAME`-mysqltemp \
	--net=$(MY_NET) \
	-e MYSQL_ROOT_PASSWORD=`cat MYSQL_PASS` \
	-d \
	local-mysql

rmmysqltemp: mysqltemp-rmkill

mysqltemp-rmkill:
	-@docker kill `cat mysqltemp`
	-@docker rm `cat mysqltemp`
	-@rm mysqltemp

rmall: rm rmmysqltemp rmmysql

grab: grabicingadir grabmysqldatadir mvdatadir

grabmysqldatadir:
	-mkdir -p datadir
	docker cp `cat mysqltemp`:/var/lib/mysql datadir/
	sudo chown -R $(user). datadir/mysql

grabicingadir:
	-mkdir -p datadir/lib
	-mkdir -p datadir/etc
	docker cp `cat cid`:/var/lib/icinga2 - |sudo tar -C datadir/lib/ -pxvf -
	docker cp `cat cid`:/etc/icinga - |sudo tar -C datadir/etc/ -pxvf -
	docker cp `cat cid`:/etc/icinga2 - |sudo tar -C datadir/etc/ -pxvf -
	docker cp `cat cid`:/etc/icinga2-classicui - |sudo tar -C datadir/etc/ -pxvf -
	docker cp `cat cid`:/etc/icingaweb2 - |sudo tar -C datadir/etc/ -pxvf -

mvdatadir:
	sudo mv datadir /tmp
	echo /tmp/datadir > DATADIR
	echo "Move datadir out of tmp and update DATADIR here accordingly for persistence"

DATADIR:
	@while [ -z "$$DATADIR" ]; do \
		read -r -p "Enter the destination of the data directory you wish to associate with this container [DATADIR]: " DATADIR; echo "$$DATADIR">>DATADIR; cat DATADIR; \
	done ;

MYSQL_PASS:
	@while [ -z "$$MYSQL_PASS" ]; do \
		read -r -p "Enter the MySQL password you wish to associate with this container [MYSQL_PASS]: " MYSQL_PASS; echo "$$MYSQL_PASS">>MYSQL_PASS; cat MYSQL_PASS; \
	done ;

