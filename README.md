# About This Image

1. Based on debian:wheezy
1. Does not contain a database. You need to link it with a MySQL container
1. No SSH. If you need to execute commands in the context of the container, you can use [nsenter](https://github.com/jpetazzo/nsenter).
1. If the linked MySQL container supplies the database's root password, the database can automatically be created and initialized.

# How To Use This Image

Create a MySQL container, if you do not already have one.

```
docker run --name mysql -e MYSQL_ROOT_PASSWORD=<SECURE_PASSWORD> -d mysql
```

Run first-time initialization.

```
docker run -it --rm --link mysql:mysql -t joshuacox/docker-icinga2 setup
```

Take a note of the displayed MySQL passwords, then start the Icinga2 container and pass the passwords as environment variables.

```
docker run -d --link mysql:mysql -e "ICINGAWEB_DB_PASSWORD=<ICINGAWEB_DB_PASSWORD>" -e "ICINGA_DB_PASSWORD=<ICINGA_DB_PASSWORD>" joshuacox/docker-icinga2
```

# Environment Variables

When running the container, you need to pass at least the passwords to the databases as environment variables.

```
ICINGA_DB_PASSWORD
ICINGAWEB_DB_PASSWORD
```

If you are not happy with the defaults, you can use these variables:

```
ICINGA_DB_USER      (default: icinga2)
ICINGA_DATABASE     (default: icinga2)
ICINGAWEB_DB_USER   (default: icinga_web)
ICINGAWEB_DATABASE  (default: icinga_web)
```

# Volumes

This container exposes one volume that contains all configurations files for icinga, icinga-web and icinga-classicui.

```
/etc/icinga2
```

# Setting passwords

Icinga-web has the default username and password set: root/password. You should change it immediately after starting the container.

The classic UI has no users defined, so you will not be able to log in. To create a user and password, run this command from your docker host:

```
htpasswd /path/to/volume/classicui/htpasswd.users icingaadmin
```

