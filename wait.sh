#!/bin/bash
#for i in {1..22}; do echo -n '!';sleep 1; done
#echo '!'
#while ! nc -z localhost 3306; do   
    #sleep 0.1 # wait for 1/10 of the second before check again
#done
# only argument should be mysql container ID
echo -n waiting for mysql to come online...
until docker exec $1 mysqladmin -hlocalhost -p`cat MYSQL_PASS` -uroot ping &>/dev/null; do
 echo -n "."; sleep 2
done
# extra
sleep 1
