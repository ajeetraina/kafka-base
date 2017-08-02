# Kafka

FROM openjdk:8-jre-alpine

ARG kafka_version=0.11.0.0
ARG scala_version=2.12

ENV APACHE_KAFKA_VERSION=$kafka_version 
ENV APACHE_SCALA_VERSION=$scala_version
ENV APACHE_KAFKA_USER kafka 
ENV APACHE_KAFKA_HOME /opt/kafka 
ENV PATH=$PATH:/$APACHE_KAFKA_HOME/bin

RUN set -x && \
    apk upgrade --update && \
    apk add --no-cache --update wget bind-tools bash su-exec && \
    adduser -D "$APACHE_KAFKA_USER" & \
    mkdir /opt && \
    wget -q http://apache.mirrors.spacedump.net/kafka/"$APACHE_KAFKA_VERSION"/kafka_"$APACHE_SCALA_VERSION"-"$APACHE_KAFKA_VERSION".tgz -O /tmp/kafka_"$APACHE_SCALA_VERSION"-"$APACHE_KAFKA_VERSION".tgz && \
    tar xfz /tmp/kafka_"$APACHE_SCALA_VERSION"-"$APACHE_KAFKA_VERSION".tgz -C /opt && \
    mv /opt/kafka_"$APACHE_SCALA_VERSION"-"$APACHE_KAFKA_VERSION" $APACHE_KAFKA_HOME && \
    rm /tmp/kafka_"$APACHE_SCALA_VERSION"-"$APACHE_KAFKA_VERSION".tgz && \
    chown -R "$APACHE_KAFKA_USER:$APACHE_KAFKA_USER" "$APACHE_KAFKA_HOME" && \
    chmod u+s /sbin/su-exec


ADD prometheus-config.yml /usr/app/prometheus-config.yml
ADD http://central.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.6/jmx_prometheus_javaagent-0.6.jar /usr/app/jmx_prometheus_javaagent.jar
RUN chmod +r /usr/app/jmx_prometheus_javaagent.jar

USER $APACHE_KAFKA_USER

WORKDIR $APACHE_KAFKA_HOME

COPY create-topics.sh /usr/bin/create-topics.sh
COPY docker-entrypoint.sh /
 
ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/opt/kafka/bin/kafka-server-start.sh","config/server.properties"]
