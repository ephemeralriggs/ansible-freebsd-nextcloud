#!/bin/sh

set -e

service postgresql initdb && \
touch /var/db/postgres/PSQL_INITDB_DONE
