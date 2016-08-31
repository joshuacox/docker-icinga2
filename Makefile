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

auto: temp waitforport4080 wait next waitforport4080

build: NAME TAG builddocker

# run a plain container
run: rm build waitformysql rundocker

# run a  container that requires mysql temporarily
temp: HOSTNAME DOMAIN MYSQL_PASS rm build mysqltemp waitformysqltemp runtemp

next: grab rmtemp rmmysqltemp wait mover wait prod
# run a  container that requires mysql in production with persistent data
# HINT: use the grabmysqldatadir recipe to grab the data directory automatically from the above runmysql
prod: HOSTNAME DOMAIN DATADIR MYSQL_PASS mysqlCID waitformysql runprod

mailvars: SMTP_ENABLED SMTP_USER SMTP_PASS SMTP_DOMAIN SMTP_PORT DOMAIN HOSTNAME

offtemp:
	$(eval TMP := $(shell mktemp -d --suffix=DOCKERTMP))
	chmod 777 $(TMP)
	echo $TMP

rundocker:
	$(eval NAME := $(shell cat NAME))
	$(eval TAG := $(shell cat TAG))
	@docker run --name=$(NAME) \
	--cidfile="cid" \
	-d \
	-P \
	-v /var/run/docker.sock:/run/docker.sock \
	-v $(shell which docker):/bin/docker \
	-t $(TAG)

runtemp:
	$(eval NAME := $(shell cat NAME))
	$(eval TAG := $(shell cat TAG))
	$(eval DOMAIN := $(shell cat DOMAIN))
	$(eval HOSTNAME := $(shell cat HOSTNAME))
	@docker run --name=$(NAME) \
	--cidfile="tempCID" \
	-d \
	-p 4080:80 \
	-p 4443:443 \
	-p 5665:5665 \
	--link `cat NAME`-mysqltemp:mysql \
	-t $(TAG)

runprod:
	$(eval DATADIR := $(shell cat DATADIR))
	$(eval NAME := $(shell cat NAME))
	$(eval TAG := $(shell cat TAG))
	$(eval SMTP_ENABLED := $(shell cat SMTP_ENABLED))
	$(eval SMTP_USER := $(shell cat SMTP_USER))
	$(eval SMTP_PASS := $(shell cat SMTP_PASS))
	$(eval SMTP_DOMAIN := $(shell cat SMTP_DOMAIN))
	$(eval SMTP_PORT := $(shell cat SMTP_PORT))
	$(eval DOMAIN := $(shell cat DOMAIN))
	$(eval HOSTNAME := $(shell cat HOSTNAME))
	@docker run --name=$(NAME) \
	--cidfile="icinga2CID" \
	-d \
	-p 4080:80 \
	-p 4443:443 \
	-p 5665:5665 \
	--env="SMTP_ENABLED=$(SMTP_ENABLED)" \
	--env="SMTP_USER=$(SMTP_USER)" \
	--env="SMTP_PASS=$(SMTP_PASS)" \
	--env="SMTP_DOMAIN=$(SMTP_DOMAIN)" \
	--env="SMTP_PORT=$(SMTP_PORT)" \
	--env="DOMAIN=$(DOMAIN)" \
	--env="HOSTNAME=$(HOSTNAME)" \
	--link `cat NAME`-mysql:mysql \
	-v $(DATADIR)/lib/icinga2:/var/lib/icinga2 \
	-v $(DATADIR)/etc/icinga:/etc/icinga \
	-v $(DATADIR)/etc/icinga2:/etc/icinga2 \
	-v $(DATADIR)/etc/icinga2-classicui:/etc/icinga2-classicui \
	-v $(DATADIR)/etc/icingaweb2:/etc/icingaweb2 \
	-h $(HOSTNAME).$(DOMAIN) \
	-t $(TAG)

debug:
	@echo 'pausing for mysql to settle'
	-@bash wait.sh
	@echo -n ' use "make logs" at this point to see if it fails on mysql, if so wait for a bit and and then try "make temp" again'
	$(eval DATADIR := $(shell cat DATADIR))
	$(eval TMP := $(shell mktemp -d --suffix=DOCKERTMP))
	-@chmod 777 $(TMP)
	$(eval NAME := $(shell cat NAME))
	$(eval TAG := $(shell cat TAG))
	@docker run --name=$(NAME) \
	--cidfile="debugCID" \
	-d \
	-p 4080:80 \
	-p 4443:443 \
	-p 5665:5665 \
	--link `cat NAME`-mysql:mysql \
	-v /var/run/docker.sock:/run/docker.sock \
	-v $(DATADIR)/lib/icinga2:/var/lib/icinga2 \
	-v $(DATADIR)/etc/icinga:/etc/icinga \
	-v $(DATADIR)/etc/icinga2:/etc/icinga2 \
	-v $(DATADIR)/etc/icinga2-classicui:/etc/icinga2-classicui \
	-v $(DATADIR)/etc/icingaweb2:/etc/icingaweb2 \
	-v $(TMP):/tmp \
	-v $(shell which docker):/bin/docker \
	-t $(TAG) /bin/bash

builddocker:
	@docker build -t `cat TAG` .

kill: SHELL:=/bin/bash
kill:
	-@ echo "killing Icinga2 container"
	-@docker kill `cat icinga2CID`

rm-image: SHELL:=/bin/bash
rm-image:
	-@ echo "removing Icinga2 container"
	-@docker rm `cat icinga2CID`
	-@rm -f icinga2CID

rm: kill rm-image

rmtemp: killtemp rmtemp-image

killtemp: SHELL:=/bin/bash
killtemp:
	-@ echo "killing Icinga2 container"
	-@docker kill `cat tempCID`

rmtemp-image: SHELL:=/bin/bash
rmtemp-image:
	-@ echo "removing Icinga2 container"
	-@docker rm `cat tempCID`
	-@rm -f tempCID

clean: rmall

enter:
	docker exec -i -t `cat icinga2CID` /bin/bash

templogs:
	docker logs -f `cat tempCID`

logs:
	docker logs -f `cat icinga2CID`

NAME:
	@while [ -z "$$NAME" ]; do \
		read -r -p "Enter the name you wish to associate with this container [NAME]: " NAME; echo "$$NAME">NAME; cat NAME; \
	done ;

TAG:
	@while [ -z "$$TAG" ]; do \
		read -r -p "Enter the tag you wish to associate with this container [TAG]: " TAG; echo "$$TAG">TAG; cat TAG; \
	done ;

DOMAIN:
	@while [ -z "$$DOMAIN" ]; do \
		read -r -p "Enter the DOMAIN you wish to associate with this container [DOMAIN]: " DOMAIN; echo "$$DOMAIN">DOMAIN; cat DOMAIN; \
	done ;

HOSTNAME:
	@while [ -z "$$HOSTNAME" ]; do \
		read -r -p "Enter the HOSTNAME you wish to associate with this container [HOSTNAME]: " HOSTNAME; echo "$$HOSTNAME">HOSTNAME; cat HOSTNAME; \
	done ;

SMTP_USER:
	@while [ -z "$$SMTP_USER" ]; do \
		read -r -p "Enter the smtp_user you wish to associate with this container [SMTP_USER]: " SMTP_USER; echo "$$SMTP_USER">SMTP_USER; cat SMTP_USER; \
	done ;

SMTP_PASS:
	@while [ -z "$$SMTP_PASS" ]; do \
		read -r -p "Enter the smtp_pass you wish to associate with this container [SMTP_PASS]: " SMTP_PASS; echo "$$SMTP_PASS">SMTP_PASS; cat SMTP_PASS; \
	done ;

SMTP_PORT:
	@while [ -z "$$SMTP_PORT" ]; do \
		read -r -p "Enter the port you wish to associate with this container [SMTP_PORT]: " SMTP_PORT; echo "$$SMTP_PORT">SMTP_PORT; cat SMTP_PORT; \
	done ;

SMTP_ENABLED:
	@while [ -z "$$SMTP_ENABLED" ]; do \
		read -r -p "If you wish to enable smtp for this container type anything here [SMTP_ENABLED]: " SMTP_ENABLED; echo "$$SMTP_ENABLED">SMTP_ENABLED; cat SMTP_ENABLED; \
	done ;

SMTP_DOMAIN:
	@while [ -z "$$SMTP_DOMAIN" ]; do \
		read -r -p "Enter the SMTP_DOMAIN you wish to associate with this container [SMTP_DOMAIN]: " SMTP_DOMAIN; echo "$$SMTP_DOMAIN">SMTP_DOMAIN; cat SMTP_DOMAIN; \
	done ;

# MYSQL additions
# use these to generate a mysql container that may or may not be persistent

mysqlCID:
	$(eval DATADIR := $(shell cat DATADIR))
	docker run \
	--cidfile="mysqlCID" \
	--name `cat NAME`-mysql \
	-d \
	-v $(DATADIR)/mysql:/var/lib/mysql \
	mysql:5.7

rmmysql: mysqlCID-rmkill

mysqlCID-rmkill:
	-@echo "killing mysql container"
	-@docker kill `cat mysqlCID`
	-@echo "removing mysql container"
	-@docker rm `cat mysqlCID`
	-@echo "removing mysqlCID"
	-@rm -f mysqlCID

rmmysqltemp: mysqltempCID-rmkill

mysqltempCID-rmkill:
	-@echo "killing mysql temp container"
	-@docker kill `cat mysqltempCID`
	-@echo "removing mysql temp container"
	-@docker rm `cat mysqltempCID`
	-@echo "removing mysqltempCID"
	-@rm -f mysqltempCID

# This one is ephemeral and will not persist data
mysqltemp: mysqltempCID

mysqltempCID:
	docker run \
	--cidfile="mysqltempCID" \
	--name `cat NAME`-mysqltemp \
	-e MYSQL_ROOT_PASSWORD=`cat MYSQL_PASS` \
	-d \
	mysql:5.7

rmall: rm rmtemp  rmmysql rmmysqltemp

grab: grabicingadir grabmysqldatadir mvdatadir

grabmysqldatadir:
	-mkdir -p datadir
	docker cp `cat mysqltempCID`:/var/lib/mysql  - |sudo tar -C datadir/ -pxvf -

grabicingadir:
	-mkdir -p datadir/lib
	-mkdir -p datadir/etc
	docker cp `cat tempCID`:/var/lib/icinga2 - |sudo tar -C datadir/lib/ -pxvf -
	docker cp `cat tempCID`:/etc/icinga - |sudo tar -C datadir/etc/ -pxvf -
	docker cp `cat tempCID`:/etc/icinga2 - |sudo tar -C datadir/etc/ -pxvf -
	docker cp `cat tempCID`:/etc/icinga2-classicui - |sudo tar -C datadir/etc/ -pxvf -
	docker cp `cat tempCID`:/etc/icingaweb2 - |sudo tar -C datadir/etc/ -pxvf -

mvdatadir:
	sudo mv datadir /tmp
	echo /tmp/datadir > DATADIR
	echo "Move datadir out of tmp and update DATADIR here accordingly for persistence"

DATADIR:
	@while [ -z "$$DATADIR" ]; do \
		read -r -p "Enter the destination of the data directory you wish to associate with this container [DATADIR]: " DATADIR; echo "$$DATADIR">DATADIR; cat DATADIR; \
	done ;

MYSQL_PASS:
	@tr -cd '[:alnum:]' < /dev/urandom | fold -w20 | head -n1 > MYSQL_PASS

askMYSQL_PASS:
	@while [ -z "$$MYSQL_PASS" ]; do \
		read -r -p "Enter the MySQL password you wish to associate with this container [MYSQL_PASS]: " MYSQL_PASS; echo "$$MYSQL_PASS">MYSQL_PASS; cat MYSQL_PASS; \
	done ;

update: update-config rm prod

update-config:
	docker exec -i -t `cat icinga2CID` sh -c '/usr/sbin/icinga2 node update-config'

pki:
	-@rm -f NEW_PKI_CN
	@while [ -z "$$NEW_PKI_CN" ]; do \
		read -r -p "Enter the common name (CN) you wish to this icinga2 instance [NEW_PKI_CN]: " NEW_PKI_CN; echo "'$$NEW_PKI_CN'">NEW_PKI_CN; cat NEW_PKI_CN; \
	done ;
	docker exec -i -t `cat icinga2CID` sh -c "/usr/sbin/icinga2 pki ticket --cn `cat NEW_PKI_CN`"
	-@rm -f NEW_PKI_CN

nodelist:
	docker exec -i -t `cat icinga2CID` sh -c '/usr/sbin/icinga2 node list'

mover:
	-@mkdir -p /exports/icinga2
	-@cd /exports; tar zcf /exports/icinga2-`date -I`.tar.gz icinga2
	-@rm -Rf /exports/icinga2/datadir
	-@mv /tmp/datadir /exports/icinga2/
	-@echo /exports/icinga2/datadir > DATADIR

hardclean: hardcleanMEAT rmall

hardcleanMEAT:
	-@rm -Rf /exports/icinga2 &>/dev/null
	-@rm -f DATADIR &>/dev/null

wait:
	-@sleep 5

waitformysql:
	-@sleep 3
	-@bash wait.sh `cat mysqlCID`
	-@sleep 3

waitformysqltemp:
	-@sleep 3
	-@bash wait.sh `cat mysqltempCID`
	-@sleep 3
	-@echo 'discombobulating combubulator'
	-@sleep 3
	-@echo 'combobulating discombubulator'
	-@sleep 3
	-@echo 'seek quell state'
	-@sleep 3

waitforport4080:
	-@sleep 3
	@echo -n "Waiting for port 4080 to become available"
	@while ! curl --output /dev/null --silent --head --fail http://localhost:4080; do sleep 2 && echo -n .; done;
	@echo "  check port 4080, it appears that now it is up!"
	-@sleep 3
