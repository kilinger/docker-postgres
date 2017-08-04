#!/bin/bash
set -e

for db in $(echo $DATABASES | tr ";" "\n")
do
	echo "Create database $database"
	gosu postgres postgres --single -jE <<-EOSQL
		CREATE DATABASE $db;
	EOSQL
	echo
done
