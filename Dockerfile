FROM nebo15/alpine-java:latest
MAINTAINER Nebo#15 <support@nebo15.com>

# Important! Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT=2016-10-14 \
    LANG=en_US.UTF-8 \
    TERM=xterm \
    HOME=/

# Install gosu
ENV GOSU_VERSION=1.10
RUN set -x && \
    apk add --no-cache --virtual .gosu-deps \
        dpkg \
        gnupg \
        openssl && \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" && \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
    rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc && \
    chmod +x /usr/local/bin/gosu && \
    gosu nobody true && \
    apk --purge del .gosu-deps

# Install Cassandra
ENV CASSANDRA_VERSION=3.9 \
    CASSANDRA_HOME=/opt/cassandra \
    CASSANDRA_CONFIG=/etc/cassandra \
    CASSANDRA_DATA=/var/lib/cassandra/data \
    CASSANDRA_LOG=/var/log/cassandra \
    CASSANDRA_USER=cassandra

## Create data directories that should be used by Cassandra
RUN mkdir -p ${CASSANDRA_DATA} \
             ${CASSANDRA_CONFIG} \
             ${CASSANDRA_LOG}

## Install it and reduce container size
RUN apk --update --no-cache add wget ca-certificates tar && \
    wget http://artfiles.org/apache.org/cassandra/${CASSANDRA_VERSION}/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz -P /tmp && \
    tar -xvzf /tmp/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz -C /tmp/ && \
    mv /tmp/apache-cassandra-${CASSANDRA_VERSION} ${CASSANDRA_HOME} && \
    apk --purge del wget ca-certificates tar && \
    rm -r /tmp/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz \
          /var/cache/apk/*

# Setup entrypoint and bash to execute it
RUN apk add --update --no-cache bash
COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

# Add default config
ADD cassandra.yaml ${CASSANDRA_CONFIG}/cassandra.yaml

# Change directories ownership and access rights
RUN adduser -D -s /bin/sh ${CASSANDRA_USER}
RUN chown -R ${CASSANDRA_USER}:${CASSANDRA_USER} ${CASSANDRA_HOME} \
                                                 ${CASSANDRA_DATA} \
                                                 ${CASSANDRA_CONFIG} \
                                                 ${CASSANDRA_LOG} && \
    chmod 777 ${CASSANDRA_HOME} \
              ${CASSANDRA_DATA} \
              ${CASSANDRA_CONFIG} \
              ${CASSANDRA_LOG}

USER ${CASSANDRA_USER}
WORKDIR ${CASSANDRA_HOME}

# Expose data volume
VOLUME ${CASSANDRA_DATA}

# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL
# 9160: thrift service
EXPOSE 7000 7001 7199 9042 9160

CMD ["bin/cassandra", "-f"]
