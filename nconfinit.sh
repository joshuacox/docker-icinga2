#!/bin/bash

## enable idoutils and pnp4nagios
cp /usr/share/doc/icinga-idoutils/examples/idoutils.cfg-sample /etc/icinga/modules/idoutils.cfg
sed -i 's/IDO2DB=no/IDO2DB=yes/g' /etc/default/icinga

cat <<EOF >/etc/icinga/modules/pnp4nagios.cfg
define module{
        module_name     npcdmod
        module_type     neb
        path            /usr/lib/pnp4nagios/npcdmod.o
        args            config_file=/etc/pnp4nagios/npcd.cfg
    }
EOF

sed -i 's/RUN="no"/RUN="yes"/g' /etc/default/npcd
sed -i '14s/nagios3/icinga/g' /etc/pnp4nagios/apache.conf

## create new home directory for user nagios
## change nagios user home directory and default shell
## create ssh key
#useradd -m nagios
mkdir -p /home/nagios/.ssh
chown -R nagios:nagios /home/nagios
sed -i 's/\/var\/lib\/nagios\:\/bin\/false/\/home\/nagios\:\/bin\/bash/g' /etc/passwd
su - nagios
ssh-keygen -b 2048
exit


## install nconf
cd /home/nagios
wget http://downloads.sourceforge.net/project/nconf/nconf/1.3.0-0/nconf-1.3.0-0.tgz
tar xfz nconf-1.3.0-0.tgz && rm nconf-1.3.0-0.tgz && cd nconf

mysql -u root -p -e "CREATE DATABASE nconf;"
mysql -u root -p -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, LOCK TABLES ON nconf.* TO 'nconf'@'localhost' IDENTIFIED BY 'secure password';"
wget https://blog.bashpipe.org/dl/nconf.initial.sql.gz
zcat nconf.initial.sql.gz | mysql -u root -p nconf

rm -Rf config/
mv config.orig/ config/
nano config/mysql.php

chown -R www-data:nagios config/ output/ static_cfg/ temp/
rm -Rf INSTALL* UPDATE*
cd /home/nagios/nconf/bin
ln -s /usr/sbin/icinga icinga
sed -i '11s/$nconfdir/\"\/home\/nagios\/nconf\"/' /home/nagios/nconf/config/nconf.php
sed -i '23s/\/var\/www\/nconf\/bin\/nagios/\/home\/nagios\/nconf\/bin\/icinga/' /home/nagios/nconf/config/nconf.php
cp /home/nagios/nconf/ADD-ONS/deploy_local.sh /home/nagios/nconf/ADD-ONS/deploy_prod.sh
chown nagios:nagios /home/nagios/nconf/ADD-ONS/deploy_prod.sh
sed -i 's/^\(OUTPUT_DIR=\).*/\1\"\/home\/nagios\/nconf\/output\/"/g' /home/nagios/nconf/ADD-ONS/deploy_prod.sh
sed -i 's/^\(NAGIOS_DIR=\).*/\1"\/etc\/icinga\/nconf.d"/g' /home/nagios/nconf/ADD-ONS/deploy_prod.sh
sed -i 's/^\(TEMP.*\)\("\)\(.*\)\("\)/\1-\2\3\4/g' /home/nagios/nconf/ADD-ONS/deploy_prod.sh
sed -i 's/nagios reload/icinga reload/g' /home/nagios/nconf/ADD-ONS/deploy_prod.sh
chmod 755 /home/nagios/nconf/ADD-ONS/deploy_prod.sh

cat <<EOF >/home/nagios/nconf/apache2.conf
Alias /nconf /home/nagios/nconf
<Directory /home/nagios/nconf>
        Options FollowSymLinks

        DirectoryIndex index.php

        #AllowOverride AuthConfig
        #Order Allow,Deny
        #Allow From All

        AuthName "Icinga Access"
        AuthType Basic
                AuthUserFile /etc/icinga/htpasswd.users
                require user icingaadmin
        Deny from all
        Satisfy any
</Directory>
EOF

ln -s /home/nagios/nconf/apache2.conf /etc/apache2/conf.d/nconf
