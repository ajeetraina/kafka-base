# kafka-base
Docker swarm kafka implementation
KUDOS  
Credit to "wustmeister/kafka" https://github.com/wurstmeister/kafka-docker for create-topics.sh to create topics on start up. This has an advantage to ensure correct number of replicas and partitions. Leaving it to devs, it is probably that they will not know the setup and not have redundant topics.  

NOTE:   
The below compose files show how to spin up a cluster isolated for an application: Graylog . You can make it generic, or replace "graylog" with whatever. It is for example, not in anyway related to the actual graylog application.  

Description:  
This image is using kafka version: kafka_2.11-0.10.1.0.tgz and the latest official zookeeper. In the example below, I am creating a kafka/zookeeper cluster to send messages through kafka to graylog, so I am going to name the stack: "graylog". As a result, you will see volumes and networks with the word "graylog" pre-pended. The rexray driver will create EBS backed volumes at a default size, or you can pre-create the volumes in AWS with a size you want and give it a TAG that mirros the volume names in the docker-compose.yml. This setup allows communication for applications running in the swarm cluster through internal networks, as well as external applications by referencing a DNS name. Although you can combine both docker-compose files below, bear in mind that kafka is much happier if zookeeper is up and running prior to starting. As a result, I separated them.  

Assumptions:  
This documentation assumes the following are in place:  
3 node cluster:  
1)  
awsswarm-1 - In AWS availability zone: us-west-2a  
awsswarm-2 - in AWS availability zone: us-west-2b  
awsswarm-3 - in AWS availability zone: us-west-2c  
  
2)  
Install the rexray driver on each swarm node   
  
3)  
You have created 3 labels, one on each host respectively  
node.labels.aws.availabilityzone == us-west-2a  
node.labels.aws.availabilityzone == us-west-2b  
node.labels.aws.availabilityzone == us-west-2c  
  
4)  
You have a DNS entry, named: swarm.aws.example.com with the ip addresses of each swarm node.  
  
5)  
You create the 3 kafka volumes externally. Run the command on each swarm node, based on the availability zone, for example, on awsswarm-1, run the command:  
docker volume create --driver rexray/ebs --opt availabilityzone=us-west-2a graylog_kafka0  
  
Gotchas:  
  
I am reserving memory for each of the containers below. If you spin these up locally with docker-machine, you may not have the resources. Simply comment out the resources stanza for each container, and re-deploy.  
Rexray will auto create EBS volumes in the same availability zone as the swarm node, so if you do not bind the container to a host and it starts on a node in another availability zone, rexray will re-create the volume.  
If you remove the stack and the EBS volume did not detach cleanly from the swarm node, rexray will re-create it.
Configuration:  
For Zookeeper, consult the official zookeeper documentation.  
For Kafka, simply add any kafka configuration variable pre-pended with "KAFKA", and replace and dots "." with underscore "". In other words, you build the server.properties file for kafka with environmental variable. For example for the kafka config varilable: "broker.id", you would put the following in the docker-compose.yml file: "KAFKA_BROKER_ID".  
  
Simple Configuration:   
Creates 1 zookeeper node and 1 kafka node.  
  
1) Deploy the zookeeper stack by copying the following docker-compose.yml and doing a "docker stack deploy -c docker-compose.yml" graylog_zookeeper  

```
version: '3.1'
services:
 zookeeper1:
    image: zookeeper
    environment:
        ZOO_MY_ID: 1
        ZOO_SERVERS: server.1=0.0.0.0:2888:3888 
        JVMFLAGS: "-Xmx512M -Xms256M"
    ports:
      - "2081:2181"
    networks:
      - net
    volumes:
      - graylog_zookeeper1_datalog:/datalog
      - graylog_zookeeper1_data:/data

networks:
  net:
    driver: overlay

volumes:
  graylog_zookeeper1_datalog:
  graylog_zookeeper1_data:  
  ```
2) Deploy the kafka stack by copying the following docker-compose.yml and doing a "docker stack deploy -c docker-compose.yml" graylog_kafka  
```
version: '3.1'
services:
 kafka0:
    image: clgriffin17/kafka-base:0.1.1
    environment:
        KAFKA_BROKER_ID: 0
        KAFKA_ZOOKEEPER_CONNECT: zookeeper1:2181
        KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9080
        KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka0:9080
        KAFKA_LOG_DIRS: "/kafka/data"
        KAFKA_HEAP_OPTS: "-Xmx512M -Xms256M"
        KAFKA_DELETE_TOPIC_ENABLE: "true"
        KAFKA_LOG_RETENTION_HOURS: 24
        KAFKA_LOG_CLEANUP_POLICY: "delete"
        KAFKA_SEGMENT_BYTES: 104857600
        KAFKA_CREATE_TOPICS: "Topic1:1:3,Topic2:1:1:compact"
        KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 3000
    networks:
      - graylog_zookeeper_net
    ports:
      - "9080:9080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - graylog_kafka0:/kafka/data

networks:
  graylog_zookeeper_net:
    external: true

volumes:
  graylog_kafka0:
    external: true  
    ```
Complex Cluster Configuration:   
Complex Swarm Configuration consisting of 3 kafka nodes and 3 zookeeper nodes backed by EBS volume using the rexray driver.
  
1) Deploy the zookeeper stack by copying the following docker-compose.yml and doing a "docker stack deploy -c docker-compose.yml" graylog_zookeeper  
  ```
version: '3.1'
services:
 zookeeper1:
    image: zookeeper
    environment:
        ZOO_MY_ID: 1
        ZOO_SERVERS: server.1=0.0.0.0:2888:3888 server.2=zookeeper2:2888:3888 server.3=zookeeper3:2888:3888
        JVMFLAGS: "-Xmx512M -Xms256M"
    deploy:
      resources:
        reservations:
          memory: 256m
        limits:
          memory: 512m
      restart_policy:
        condition: on-failure
        delay: 0s
        max_attempts: 3
        window: 120s
      placement:
        constraints:
          - node.hostname == awsswarm-1
    ports:
      - "2081:2181"
    networks:
      - net
    volumes:
      - graylog_zookeeper1_datalog:/datalog
      - graylog_zookeeper1_data:/data
 zookeeper2:
    image: zookeeper
    environment:
        ZOO_MY_ID: 2
        ZOO_SERVERS: server.1=zookeeper1:2888:3888 server.2=0.0.0.0:2888:3888 server.3=zookeeper3:2888:3888
        JVMFLAGS: "-Xmx512M -Xms256M"
    deploy:
      resources:
        reservations:
          memory: 256m
        limits:
          memory: 512m
      restart_policy:
        condition: on-failure
        delay: 10s
        max_attempts: 3
        window: 120s
      placement:
        constraints:
          - node.hostname == awsswarm-2
    ports:
      - "2082:2181"
    networks:
      - net
    volumes:
      - graylog_zookeeper2_datalog:/datalog
      - graylog_zookeeper2_data:/data
 zookeeper3:
    image: zookeeper
    environment:
        ZOO_MY_ID: 3
        ZOO_SERVERS: server.1=zookeeper1:2888:3888 server.2=zookeeper2:2888:3888 server.3=0.0.0.0:2888:3888
        JVMFLAGS: "-Xmx512M -Xms256M"
    deploy:
      resources:
        reservations:
          memory: 256m
        limits:
          memory: 512m
      restart_policy:
        condition: on-failure
        delay: 20s
        max_attempts: 3
        window: 120s
      placement:
        constraints:
          - node.hostname == awsswarm-3
    ports:
      - "2083:2181"
    networks:
      - net
    volumes:
      - graylog_zookeeper3_datalog:/datalog
      - graylog_zookeeper3_data:/data

networks:
  net:
    driver: overlay

volumes:
  graylog_zookeeper1_datalog:
  graylog_zookeeper1_data:
  graylog_zookeeper2_datalog:
  graylog_zookeeper2_data:
  graylog_zookeeper3_datalog:
  graylog_zookeeper3_data: 
  ```
2) Deploy the kafka stack by copying the following docker-compose.yml and doing a "docker stack deploy -c docker-compose.yml" graylog_kafka  
  ```
version: '3.1'
services:
 kafka0:
    image: clgriffin17/kafka-base:0.1.1
    environment:
        KAFKA_BROKER_ID: 0
        KAFKA_ZOOKEEPER_CONNECT: zookeeper1:2181,zookeeper2:2181,zookeeper3:2181
        KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9080
        KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://swarm.aws.example.com:9080
        KAFKA_LOG_DIRS: "/kafka/data"
        KAFKA_HEAP_OPTS: "-Xmx1G -Xms1G"
        KAFKA_DELETE_TOPIC_ENABLE: "true"
        KAFKA_LOG_RETENTION_HOURS: 24
        KAFKA_LOG_CLEANUP_POLICY: "delete"
        KAFKA_SEGMENT_BYTES: 104857600
        KAFKA_CREATE_TOPICS: "Topic1:1:3,Topic2:1:1:compact"
        KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 3000

    deploy:
      placement:
        constraints:
          - node.labels.aws.availabilityzone == us-west-2a 
      resources:
        reservations:
          memory: 1g
        limits:
          memory: 1.25g
      restart_policy:
        condition: on-failure
        delay: 10s
        max_attempts: 3
        window: 120s
    networks:
      - graylog_zookeeper_net
    ports:
      - "9080:9080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - graylog_kafka0:/kafka/data
 kafka1:
    image: clgriffin17/kafka-base:0.1.1
    environment:
        KAFKA_BROKER_ID: 1
        KAFKA_ZOOKEEPER_CONNECT: zookeeper1:2181,zookeeper2:2181,zookeeper3:2181
        KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9081
        KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://swarm.aws.example.com:9081
        KAFKA_LOG_DIRS: "/kafka/data"
        KAFKA_HEAP_OPTS: "-Xmx1G -Xms1G"
        KAFKA_DELETE_TOPIC_ENABLE: "true"
        KAFKA_LOG_RETENTION_HOURS: 24
        KAFKA_LOG_CLEANUP_POLICY: "delete"
        KAFKA_SEGMENT_BYTES: 104857600
        KAFKA_CREATE_TOPICS: "Topic1:1:3,Topic2:1:1:compact"
        KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 3000

    deploy:
      placement:
        constraints:
          - node.labels.aws.availabilityzone == us-west-2b 
      resources:
        reservations:
          memory: 1g
        limits:
          memory: 1.25g
      restart_policy:
        condition: on-failure
        delay: 10s
        max_attempts: 3
        window: 120s
    ports:
      - "9081:9081"
    networks:
      - graylog_zookeeper_net
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - graylog_kafka1:/kafka/data
 kafka2:
    image: clgriffin17/kafka-base:0.1.1
    environment:
        KAFKA_BROKER_ID: 2
        KAFKA_ZOOKEEPER_CONNECT: zookeeper1:2181,zookeeper2:2181,zookeeper3:2181
        KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9082
        KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://swarm.aws.example.com:9082
        KAFKA_LOG_DIRS: "/kafka/data"
        KAFKA_HEAP_OPTS: "-Xmx1G -Xms1G"
        KAFKA_DELETE_TOPIC_ENABLE: "true"
        KAFKA_LOG_RETENTION_HOURS: 24
        KAFKA_LOG_CLEANUP_POLICY: "delete"
        KAFKA_SEGMENT_BYTES: 104857600
        KAFKA_CREATE_TOPICS: "Topic1:1:3,Topic2:1:1:compact"
        KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 3000

    deploy:
      placement:
        constraints:
          - node.labels.aws.availabilityzone == us-west-2c
      resources:
        reservations:
          memory: 1g
        limits:
          memory: 1.25g
      restart_policy:
        condition: on-failure
        delay: 10s
        max_attempts: 3
        window: 120s
    ports:
      - "9082:9082"
    networks:
      - graylog_zookeeper_net

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - graylog_kafka2:/kafka/data

networks:
  graylog_zookeeper_net:
    external: true


volumes:
  graylog_kafka0:
    external: true
  graylog_kafka1:
    external: true
  graylog_kafka2:
    external: true
    ```
