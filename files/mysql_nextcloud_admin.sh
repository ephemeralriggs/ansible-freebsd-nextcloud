#!/bin/sh

set -e

ROOTPASSWORD=$1
NCUSERNAME=$2
NCUSERPASSWORD=$3

if [ "x$ROOTPASSWORD" = "x" ]; then exit 1; fi
if [ "x$NCUSERNAME" = "x" ]; then exit 1; fi
if [ "x$NCUSERPASSWORD" = "x" ]; then exit 1; fi

mysql -u root -p$ROOTPASSWORD << EOF
CREATE DATABASE nextcloud;
CREATE USER '$NCUSERNAME'@'localhost' IDENTIFIED BY '$NCUSERPASSWORD';
GRANT ALL ON nextcloud.* TO '$NCUSERNAME'@'localhost';
FLUSH PRIVILEGES;
EOF

touch /var/db/mysql_secure/MYSQL_NEXTCLOUD_ADMIN_DONE
