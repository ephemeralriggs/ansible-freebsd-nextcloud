#!/bin/sh

set -e

PASSWORD=$1

if [ "x$PASSWORD" = "x" ]; then exit 1; fi

mysql -u root << EOF
UPDATE mysql.user SET Password=PASSWORD('$PASSWORD') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF

touch /var/db/mysql_secure/MYSQL_SECURE_DONE
