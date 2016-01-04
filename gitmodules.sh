#!/bin/bash
TMP_DIR=$(mktemp -d --suffix='.icingaweb2')
cd $TMP_DIR

# got this from here https://hub.docker.com/r/jordan/icinga2/~/dockerfile/
# modified to use mktemp
# Temporary hack to get icingaweb2 modules via git
mkdir -p /etc/icingaweb2/enabledModules
rm -Rf /etc/icingaweb2/enabledModules/*
wget --no-cookies "https://github.com/Icinga/icingaweb2/archive/master.zip" -O $TMP_DIR/icingaweb2.zip
unzip $TMP_DIR/icingaweb2.zip "icingaweb2-master/modules/doc/*" "icingaweb2-master/modules/monitoring/*" -d "$TMP_DIR/icingaweb2"
cp -R $TMP_DIR/icingaweb2/icingaweb2-master/modules/monitoring /etc/icingaweb2/enabledModules/
cp -R  $TMP_DIR/icingaweb2/icingaweb2-master/modules/doc /etc/icingaweb2/enabledModules/

cd
rm -Rf $TMP_DIR
