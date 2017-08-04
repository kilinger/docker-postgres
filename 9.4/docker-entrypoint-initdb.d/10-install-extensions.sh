#!/bin/bash
set -e

for ext in $(echo $EXTENSIONS | tr ";" "\n")
do
	echo "Create extension $ext for template1"
	gosu postgres postgres --single template1 -jE <<-EOSQL
		CREATE EXTENSION $ext;
	EOSQL
	echo
done
