#!/bin/bash

set -e

#The following pulled from wurstmeister
for VAR in $(env)
do
  if [[ $VAR =~ ^KAFKA_ ]]; then
    kafka_name=`echo "$VAR" | sed -r "s/KAFKA_(.*)=.*/\1/g" | tr '[:upper:]' '[:lower:]' | tr _ .`
    env_var=`echo "$VAR" | sed -r "s/(.*)=.*/\1/g"`
    if egrep -q "(^|^#)$kafka_name=" $APACHE_KAFKA_HOME/config/server.properties; then
        sed -r -i "s@(^|^#)($kafka_name)=(.*)@\2=${!env_var}@g" $APACHE_KAFKA_HOME/config/server.properties #note that no config values may contain an '@' char
    else
        echo "$kafka_name=${!env_var}" >> $APACHE_KAFKA_HOME/config/server.properties
    fi
  fi
done

#Change ownership of mapped data volume...
/sbin/su-exec root chown -R kafka:kafka /kafka

/usr/bin/create-topics.sh &

exec "$@"
