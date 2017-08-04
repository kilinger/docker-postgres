FROM index.xxxxx.com/postgres:9.4

MAINTAINER heww0205@gmail.com

# Replication ENV
ENV REPLICATION_MASTER **False**
ENV REPLICATION_SLAVE **False**
ENV REPLICATION_USER replica
ENV REPLICATION_PASS replica
ENV REPLICATION_MASTER_HOST **False**
ENV REPLICATION_MASTER_PORT 5432

COPY docker-entrypoint.sh /
COPY docker-entrypoint-initdb.d/* docker-entrypoint-initdb.d/
