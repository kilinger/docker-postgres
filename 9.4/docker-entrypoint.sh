#!/bin/bash
set -e


PostgresExec()
{
	gosu postgres postgres --single -jE <<-EOSQL
	$1;
	EOSQL
	echo
}

CreateReplicationUser()
{
	echo "Create user for replication"
	PostgresExec "CREATE ROLE $REPLICATION_USER WITH REPLICATION PASSWORD '$REPLICATION_PASS' LOGIN"
}

AppendToConfig()
{
	# $1 is config file in $PGDATA, $2 is content append to
	{ echo; echo "$2"; } >> "$PGDATA"/$1
}

Mkdir()
{
	mkdir -p $PGDATA/$1
	chown postgres:postgres -R $PGDATA/$1
}

ConfigMaster()
{
	echo "Config postgresql.conf for master"
	Mkdir "archive"

	AppendToConfig "postgresql.conf" "wal_level = hot_standby"
	AppendToConfig "postgresql.conf" "max_wal_senders = 3"
	AppendToConfig "postgresql.conf" "wal_keep_segments = 30"
	AppendToConfig "postgresql.conf" "archive_mode = on"
	AppendToConfig "postgresql.conf" "archive_command = 'test ! -f $PGDATA/archive/%f && cp %p $PGDATA/archive/%f'"  # Unix  
	AppendToConfig "postgresql.conf" "archive_timeout = 3600"

	echo "Config pg_hba.conf for master"
	AppendToConfig "pg_hba.conf" "host replication all all md5"
}


ConfigSlave()
{
	AppendToConfig "postgresql.conf" "wal_level = hot_standby"
	AppendToConfig "postgresql.conf" "max_wal_senders = 3"
	AppendToConfig "postgresql.conf" "wal_keep_segments = 30"
	AppendToConfig "postgresql.conf" "hot_standby = on"

	AppendToConfig "recovery.conf" "standby_mode = on"
	AppendToConfig "recovery.conf" "primary_conninfo = 'host=${REPLICATION_MASTER_HOST} port=${REPLICATION_MASTER_PORT} user=${REPLICATION_USER} password=${REPLICATION_PASS}'"
	AppendToConfig "recovery.conf" "trigger_file = '$PGDATA/trigger'"
	AppendToConfig "recovery.conf" "restore_command='cp ${PGDATA}/archive/%f \"%p\"'"
	AppendToConfig "recovery.conf" "archive_cleanup_command = 'pg_archivecleanup ${PGDATA}/archive %r'"
}

PgBaseBackup() 
{
	# Set password for pg_basebackup
	mkdir /home/postgres
	echo "${REPLICATION_MASTER_HOST}:${REPLICATION_MASTER_PORT}:replication:${REPLICATION_USER}:${REPLICATION_PASS}" >> /home/postgres/.pgpass
	chmod 0600 /home/postgres/.pgpass
	chown postgres:postgres -R /home/postgres
	
	echo Starting base backup as replicator

	rm -rf $PGDATA/*
	gosu postgres pg_basebackup -h ${REPLICATION_MASTER_HOST} -p ${REPLICATION_MASTER_PORT} -D $PGDATA -U ${REPLICATION_USER} -Fp -Xs -v -P --no-password
	chmod 0700 $PGDATA
}


Init()
{
	if [ ${REPLICATION_MASTER} == "**False**" ]; then
		unset REPLICATION_MASTER
	fi
	
	if [ ${REPLICATION_SLAVE} == "**False**" ]; then
		unset REPLICATION_SLAVE
	fi

	if [ ${REPLICATION_MASTER_HOST} == "**False**" ]; then
		unset REPLICATION_MASTER_HOST
	fi

	if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ] && [ -n "${POSTGRES_PORT_5432_TCP_PORT}" ]; then
		REPLICATION_MASTER_HOST=${POSTGRES_PORT_5432_TCP_ADDR}
		REPLICATION_MASTER_PORT=${POSTGRES_PORT_5432_TCP_PORT}
	fi	

	chown -R postgres "$PGDATA"
	chmod 0700 $PGDATA
}

Init

if [ "$1" = 'postgres' ]; then

	# Set Postgres REPLICATION - SLAVE
	if [ -n "${REPLICATION_SLAVE}" ]; then
		echo "=> Configuring Postgres replication as slave ..."

		if [ -n "${REPLICATION_MASTER_HOST}" ] && [ -n "${REPLICATION_MASTER_PORT}" ]; then
			if [ ! -f /replication_configured ]; then
				echo "=> Setting master connection info on slave"
				PgBaseBackup
				ConfigSlave
				echo "=> Done!"
				touch /replication_configured
			else
				echo "=> Postgres replicaiton slave already configured, skip"
			fi
		else
			echo "=> Cannot configure slave, please link it to another Postgres container with alias as 'postgres' or set REPLICATION_MASTER_HOST env"
			exit 1
		fi
	fi	

	if [ -z "$(ls -A "$PGDATA")" ]; then
		gosu postgres initdb
		
		sed -ri "s/^#(listen_addresses\s*=\s*)\S+/\1'*'/" "$PGDATA"/postgresql.conf
		
		# check password first so we can ouptut the warning before postgres
		# messes it up
		if [ "$POSTGRES_PASSWORD" ]; then
			pass="PASSWORD '$POSTGRES_PASSWORD'"
			authMethod=md5
		else
			# The - option suppresses leading tabs but *not* spaces. :)
			cat >&2 <<-'EOWARN'
				****************************************************
				WARNING: No password has been set for the database.
				         This will allow anyone with access to the
				         Postgres port to access your database. In
				         Docker's default configuration, this is
				         effectively any other container on the same
				         system.
				         
				         Use "-e POSTGRES_PASSWORD=password" to set
				         it in "docker run".
				****************************************************
			EOWARN
			
			pass=
			authMethod=trust
		fi
		
		: ${POSTGRES_USER:=postgres}
		: ${POSTGRES_DB:=$POSTGRES_USER}

		if [ "$POSTGRES_DB" != 'postgres' ]; then
			gosu postgres postgres --single -jE <<-EOSQL
				CREATE DATABASE "$POSTGRES_DB" ;
			EOSQL
			echo
		fi
		
		if [ "$POSTGRES_USER" = 'postgres' ]; then
			op='ALTER'
		else
			op='CREATE'
		fi

		gosu postgres postgres --single -jE <<-EOSQL
			$op USER "$POSTGRES_USER" WITH SUPERUSER $pass ;
		EOSQL
		echo
		
		{ echo; echo "host all all 0.0.0.0/0 $authMethod"; } >> "$PGDATA"/pg_hba.conf
		
		if [ -d /docker-entrypoint-initdb.d ]; then
			for f in /docker-entrypoint-initdb.d/*.sh; do
				[ -f "$f" ] && . "$f"
			done
		fi


	fi
	
	# Set Postgres REPLICATION - MASTER
	if [ -n "${REPLICATION_MASTER}" ]; then
		echo "=> Configuring Postgres replication as master ..."
		if [ ! -f /replication_configured ]; then
			echo "=> Done!"
			CreateReplicationUser
			ConfigMaster
			touch /replication_configured
		else
			echo "=> Postgres replication master already configured, skip"
		fi
	fi

	exec gosu postgres "$@"
fi

exec "$@"
