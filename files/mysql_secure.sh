#!/bin/sh

PASSWORD=$1

mysql -u root << EOF
UPDATE mysql.user SET Password=PASSWORD('$PASSWORD') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF

touch /var/db/mysql_secure/MYSQL_SECURE_DONE
