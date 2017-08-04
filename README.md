Postgres
======================

Base docker image to run a Postgres database server

Postgres version
----------------
Different versions are build from different folders.  


Usage
-----

To create the image `index.xxxxx.com/postgres`, execute the following command on the postgres folder:

	docker build -t index.xxxxx.com/postgres 9.4

To run the image and bind to port 5432:

	docker run -d -p 5432:5432 index.xxxxx.com/postgres

The first time that you run your container, a new user `postgres` with password `postgres` and all privileges will be created in Postgres.

Setting a specific password for the admin account
-------------------------------------------------
If you want to use another password than default `postgres` one, you can set the environment variable `POSTGRES_PASSWORD` to your specific password when running the container:

	docker run -d -p 5432:5432 -e POSTGRES_PASSWORD="mypass" index.xxxxx.com/postgres

You can now test your deployment:
	
	psql -h localhost -U postgres -W "mypass"

The admin username can also be set via the `POSTGRES_USER` environment variable.

Mounting the database file volume
----------------------------------
In order to persist the database data, you can mount a local folder from the host on the container to store database files. To do so:
	
	docker run -d -v /path/in/host:/var/lib/postgresql/data index.xxxxx.com

This will mount the local folder `/path/in/host` inside the docker in `/var/lib/postgresql/data` (where Postgres will store the database files by default).

Remember that this will mean that your host must have `/path/in/host` available when you run your docker image!

Mounting the database file volume from other containers
-------------------------------------------------------

Another way to persist the database data is to store database files in another container.
To do so, first create a container that holds database files:

	docker run -d -v /var/lib/postgresql/data --name db_vol -p 22:22 tutum/ubuntu:trusty

This will create a new ssh-enabled container and use its folder `/var/lib/postgresql/data` to store Postgres database files.
You can specify any name of the container by using `--name` option, which will be used in next step.

After this you can start you Postgres image using volumes in the container created above(put the name of container in `--volumes-from`)

	docker run -d --volumes-from db_vol -p 5432:5432 index.xxxxx.com/postgres

Replication - Master/Slave
--------------------------

To use Postgres replication, please set environment variable `REPLICATION_MASTER`/`REPLICATION_SLAVE` to `true`. Also, on master side, you may want to specify `REPLICATION_USER` and `REPLICATION_PASS` for the account to perform replication, the default value is `replica:replica`

Examples:
- Master Postgres
- 
        docker run -d -e REPLICATION_MASTER=true -e REPLICATION_PASS=mypass -p 5432:5432 --name postgres index.xxxxx.com/postgres

- Example on Slave Postgres:
- 
        docker run -d -e REPLICATION_SLAVE=true -e REPLICATION_PASS=mypass -p 5433:5432 --link postgres:postgres index.xxxxx.com/postgres

Now you can access port `5432` and `5433` for the master/slave Postgres.

If you don't like to use `--link` option, you can use `REPLICATION_MASTER_HOST` and `REPLICATION_MASTER_PORT` to connect to master. For exammple, if we have a master at remote host which address is `192.168.1.10:5432`, run the slave like this: 

	docker run -d -e REPLICATION_SLAVE=true -e REPLICATION_PASS=mypass \
		-e REPLICATION_MASTER_HOST=192.168.1.10 -e REPLICATION_MASTER_PORT=5432 -p 5433:5432 index.xxxxx.com/postgres

Environment variables
---------------------

`POSTGRES_USER`: Set a specific username for the admin account (default 'postgres').

`POSTGRES_PASSWORD`: Set a specific password for the admin account (default 'postgres').

`EXTENSIONS`: Defines one or more extensions separated by `;` to create in the `template1` database.

`DATABASES`: Defines one or more databases separated by `;` to create after `EXTENSIONS` created.
