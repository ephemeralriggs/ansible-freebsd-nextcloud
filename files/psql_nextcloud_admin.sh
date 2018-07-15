#!/bin/sh

set -e

ROOTPASSWORD=$1
NCUSERNAME=$2
NCUSERPASSWORD=$3

if [ "x$ROOTPASSWORD" = "x" ]; then exit 1; fi
if [ "x$NCUSERNAME" = "x" ]; then exit 1; fi
if [ "x$NCUSERPASSWORD" = "x" ]; then exit 1; fi

psql -U postgres << EOF
ALTER USER postgres WITH PASSWORD '$ROOTPASSWORD';
CREATE USER $NCUSERNAME WITH PASSWORD '$NCUSERPASSWORD';
CREATE DATABASE nextcloud ENCODING 'UNICODE' OWNER $NCUSERNAME;
EOF

touch /var/db/postgres/PSQL_NEXTCLOUD_ADMIN_DONE
