#!/bin/bash
set -e 

if [ -z "$MYSQL_PORT_3306_TCP" ]; then
    echo >&2 'error: missing MYSQL_PORT_3306_TCP environment variable'
    echo >&2 '  Did you forget to --link some_mysql_container:mysql ?'
    exit 1
fi

ICINGA_DATABASE=${ICINGA_DATABASE:=icinga}
ICINGA_DB_USER=${ICINGA_DB_USER:=icinga}
if [ -z "$ICINGA_DB_PASSWORD" ] ; then 
    ICINGA_DB_PASSWORD=`pwgen 32 1`
fi

#else
    # Create IDO-MySQL configuration if connection info was passed as environment variables
    #cat >/etc/icinga/features-available/ido-mysql.conf <<-EOF
#library "db_ido_mysql"

#object IdoMysqlConnection "ido-mysql" {
  #user = "$ICINGA_DB_USER",
  #password = "$ICINGA_DB_PASSWORD",
  #host = "$MYSQL_PORT_3306_TCP_ADDR",
  #database = "$ICINGA_DATABASE"
#}
#EOF
#fi

ICINGAWEB_DATABASE=${ICINGAWEB_DATABASE:=icinga_web}
ICINGAWEB_DB_USER=${ICINGAWEB_DB_USER:=icinga_web}
if [ -z "$ICINGAWEB_DB_PASSWORD" ] ; then 
    ICINGAWEB_DB_PASSWORD=`pwgen 32 1`
else
    # Create database configuration if connection info was passed as environment variables
    cat >/etc/icinga-web/conf.d/database-ido.xml <<-EOF
<?xml version="1.0" encoding="UTF-8"?>

<databases xmlns:db="http://agavi.org/agavi/config/parts/databases/1.0" xmlns:ae="http://agavi.org/agavi/config/global/envelope/1.0">

    <db:database xmlns="http://agavi.org/agavi/config/parts/databases/1.0" name="icinga" class="IcingaDoctrineDatabase">
        <ae:parameter name="dsn">mysql://$ICINGA_DB_USER:$ICINGA_DB_PASSWORD@$MYSQL_PORT_3306_TCP_ADDR:$MYSQL_PORT_3306_TCP_PORT/$ICINGA_DATABASE</ae:parameter>
    </db:database>

</databases>
EOF

    cat >/etc/icinga-web/conf.d/database-web.xml <<-EOF
<?xml version="1.0" encoding="UTF-8"?>

<databases xmlns:db="http://agavi.org/agavi/config/parts/databases/1.0" xmlns:ae="http://agavi.org/agavi/config/global/envelope/1.0">

    <db:database name="icinga_web" class="AppKitDoctrineDatabase">
        <ae:parameter name="dsn">mysql://$ICINGAWEB_DB_USER:$ICINGAWEB_DB_PASSWORD@$MYSQL_PORT_3306_TCP_ADDR:$MYSQL_PORT_3306_TCP_PORT/$ICINGAWEB_DATABASE</ae:parameter>
    </db:database>

</databases>
EOF
fi

if [ "${1,,}" == "setup" ] ; then
    echo "First time setup requested..."
    if [ -z "$MYSQL_ENV_MYSQL_ROOT_PASSWORD" ] && [ -z "$MYSQL_ROOT_PASSWORD" ] ; then
        echo >&2 "ERROR: Neither MYSQL_ENV_MYSQL_ROOT_PASSWORD nor MYSQL_ROOT_PASSWORD are set."
        echo >&2 "       To perform first-time setup, please provide MySQL's root password via"
        echo >&2 "       the MYSQL_ROOT_PASSWORD environment variable."
        echo >&2 "       Alternatively, the linked MySQL container can provide the root password"
        echo >&2 "       via the docker link."
    fi

    echo "MySQL root password is set. Using root access for first-time setup."
    echo "Dropping database $ICINGA_DATABASE..."
    echo "DROP DATABASE IF EXISTS $ICINGA_DATABASE;" | mysql -uroot "-p$MYSQL_ENV_MYSQL_ROOT_PASSWORD" "-h$MYSQL_PORT_3306_TCP_ADDR" "-P$MYSQL_PORT_3306_TCP_PORT" mysql
    echo "Dropping database $ICINGAWEB_DATABASE..."
    echo "DROP DATABASE IF EXISTS $ICINGAWEB_DATABASE;" | mysql -uroot "-p$MYSQL_ENV_MYSQL_ROOT_PASSWORD" "-h$MYSQL_PORT_3306_TCP_ADDR" "-P$MYSQL_PORT_3306_TCP_PORT" mysql

    echo "Creating database $ICINGA_DATABASE..."
    echo "CREATE DATABASE IF NOT EXISTS $ICINGA_DATABASE;" | mysql -uroot "-p$MYSQL_ENV_MYSQL_ROOT_PASSWORD" "-h$MYSQL_PORT_3306_TCP_ADDR" "-P$MYSQL_PORT_3306_TCP_PORT" mysql
    echo "Creating database $ICINGAWEB_DATABASE..."
    echo "CREATE DATABASE IF NOT EXISTS $ICINGAWEB_DATABASE;" | mysql -uroot "-p$MYSQL_ENV_MYSQL_ROOT_PASSWORD" "-h$MYSQL_PORT_3306_TCP_ADDR" "-P$MYSQL_PORT_3306_TCP_PORT" mysql
        
    echo "Creating database user $ICINGA_DB_USER..."
    echo "GRANT ALL ON $ICINGA_DATABASE.* TO '$ICINGA_DB_USER'@'%' IDENTIFIED BY '$ICINGA_DB_PASSWORD';" | mysql -uroot "-p$MYSQL_ENV_MYSQL_ROOT_PASSWORD" "-h$MYSQL_PORT_3306_TCP_ADDR" "-P$MYSQL_PORT_3306_TCP_PORT" mysql
    echo "Creating database user $ICINGAWEB_DB_USER..."
    echo "GRANT ALL ON $ICINGAWEB_DATABASE.* TO '$ICINGAWEB_DB_USER'@'%' IDENTIFIED BY '$ICINGAWEB_DB_PASSWORD';" | mysql -uroot "-p$MYSQL_ENV_MYSQL_ROOT_PASSWORD" "-h$MYSQL_PORT_3306_TCP_ADDR" "-P$MYSQL_PORT_3306_TCP_PORT" mysql
    echo "GRANT ALL ON $ICINGA_DATABASE.* TO '$ICINGAWEB_DB_USER'@'%' IDENTIFIED BY '$ICINGAWEB_DB_PASSWORD';" | mysql -uroot "-p$MYSQL_ENV_MYSQL_ROOT_PASSWORD" "-h$MYSQL_PORT_3306_TCP_ADDR" "-P$MYSQL_PORT_3306_TCP_PORT" mysql

    echo "Importing database schema into $ICINGA_DATABASE..."
    mysql "-u$ICINGA_DB_USER" "-p$ICINGA_DB_PASSWORD" "-h$MYSQL_PORT_3306_TCP_ADDR" "-P$MYSQL_PORT_3306_TCP_PORT" "$ICINGA_DATABASE" < /usr/share/dbconfig-common/data/icinga-idoutils/install/mysql

    echo "Importing database schema into $ICINGAWEB_DATABASE..."
    mysql "-u$ICINGAWEB_DB_USER" "-p$ICINGAWEB_DB_PASSWORD" "-h$MYSQL_PORT_3306_TCP_ADDR" "-P$MYSQL_PORT_3306_TCP_PORT" "$ICINGAWEB_DATABASE" < /usr/share/dbconfig-common/data/icinga-web/install/mysql

    echo 
    echo "################################################################"
    echo "## First-time setup complete.                                 ##"
    echo "## Icinga2 has been configured with the following data.       ##"
    echo "## You can now start the container in daemon mode and provide ##"
    echo "## this data via environment variables.                       ##"
    echo "################################################################"
    printf "## ICINGA_DATABASE:       %-33s ##\n" "$ICINGA_DATABASE"
    printf "## ICINGA_DB_USER:        %-33s ##\n" "$ICINGA_DB_USER"
    printf "## ICINGA_DB_PASSWORD:    %-33s ##\n" "$ICINGA_DB_PASSWORD"
    printf "## ICINGAWEB_DB_USER:     %-33s ##\n" "$ICINGAWEB_DB_USER"
    printf "## ICINGAWEB_DB_PASSWORD: %-33s ##\n" "$ICINGAWEB_DB_PASSWORD"
    printf "## ICINGAWEB_DATABASE:    %-33s ##\n" "$ICINGAWEB_DATABASE"
    echo "################################################################"
    exit 0
fi

gpasswd -a www-data nagios
mkdir -p /var/run/icinga2/cmd
chown -R nagios:nagios /var/run/icinga2
#chown -R nagios:www-data /var/run/icinga2/cmd
#chmod g+rwx /var/run/icinga2/cmd
exec "$@"
