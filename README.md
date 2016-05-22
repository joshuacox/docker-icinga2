# About This Image

1. Based on debian:jessie
1. Does not contain a database. You need to link it with a MySQL container (this is done for you by the Makefile)
1. No SSH. If you need to execute commands in the context of the container, you can use [roustabout’s EnterDocker command](http://joshuacox.github.io/roustabout/).
1. You will be prompted for the database's root password, the database will then automatically be created and initialized
1. After you run the `make grab` command you can `make rmall` and start in `make prod` mode which will be persistent (so long as you move the datadir out of `/tmp!`)

# How To Use This Image

#### Usage

should be easy first pull the temporary recipe up

```
make temp
```

then
```
make next
```

this is a very opinionated method, in that this will put your data directory into `/exports/icinga2`
if you wish to control where things go, you can do it manually. Which I describe in the next section

### Manually go through the steps

First create the temporary container so we can grab the persistent data directories
```
make temp
```

then grab all the persistent volumes

```
make grab
```

then run in `prod` mode, take this ‘prod’ with a grain of salt, I’ll leave it to you to understand all security implications of the 
MYSQL_ROOT_PASS file hanging out after these Makefiles have ran (i.e. on all docker machines you should implicitly trust all users with the ‘docker’ group as they effectively have root on the machine)

```
make prod
```

# Volumes

This container exposes one volume that contains all configurations files for icinga, icinga-web and icinga-classicui. They will all be captured with the `make grab` command

```
/etc/icinga2
```

# Setting passwords

Icinga-web has the default username and password set: root/password. You should change it immediately after starting the container.

The classic UI has no users defined, so you will not be able to log in. To create a user and password, run this command from your docker host:

```
htpasswd /path/to/volume/classicui/htpasswd.users icingaadmin
```

### Icinga Web 2

Icinga Web 2 can be accessed at http://localhost:3080/icingaweb2 w/ `icingaadmin:icinga` as credentials. (these should be changed immediately)

The configuration is located in /etc/icingaweb2 which is exposed as [volume](#volumes) from
docker.

By default the icingaweb2 database is created including the `icingaadmin` user. Additional
configuration is also added to skip the setup wizard.

## Ports

The following ports are exposed:

  Port     | Service
  ---------|---------
  22       | SSH
  80       | HTTP
  443      | HTTPS
  3306     | MySQL
  5665     | Icinga 2 API & Cluster

## Volumes

These volumes can be mounted in order to test and develop various stuff.

    /etc/icinga2
    /etc/icingaweb2

    /var/lib/icinga2
    /usr/share/icingaweb2

    /var/lib/mysql

### SMTP 

To enable mail you'll need to issue the 'mailvars' recipe

```
make mailvars
```

it will prompt you for everything or if you want to do it manually 

define the `$SMTP_ENABLED` variable which will then allow you to configure `/etc/ssmtp/ssmtp.conf`
by setting the rest of the variables 
the following variables need to be set:

```
if [ -n $SMTP_ENABLED ]; then
  echo_log "Enabling SMTP."
cat <<EOF >/etc/ssmtp/ssmtp.conf
root=postmaster
AuthUser=$SMTP_USER
AuthPass=$SMTP_PASS
mailhub=$SMTP_DOMAIN:$SMTP_PORT
UseSTARTTLS=YES
rewriteDomain=$DOMAIN
hostname=$HOSTNAME
FromLineOverride=YES
EOF
```


