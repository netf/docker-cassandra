#!/usr/bin/env bash

IP=`hostname --ip-address`
DOCKER_ENDPOINT="http://172.17.42.1:2379/"

# Setup Cassandra
CLUSTER_NAME=`curl -L ${DOCKER_ENDPOINT}/v2/keys/cassandra/cluster_name 2>/dev/null| jq  '.node.value'| sed s/[\"]//g`
CLUSTER_NAME="${CLUSTER_NAME%\\n}"
if [ ${CLUSTER_NAME} == "null" ]; then
    CLUSTER_NAME="Test Cluster"
fi
SEEDS=`curl -L ${DOCKER_ENDPOINT}/v2/keys/cassandra/seeds 2>/dev/null| jq  '.node.value'| sed s/[\"]//g`
SEEDS=${SEEDS%\\n}
if [ $SEEDS == "null" ]; then
    SEEDS="${IP}"
    curl -L -X PUT ${DOCKER_ENDPOINT}/v2/keys/cassandra/seeds -d value="${IP}" 2>/dev/null
else
    if [[ $seeds != *"${IP}"* ]]; then
      NEW_SEEDS="${SEEDS},${IP}"
      curl -L -X PUT ${DOCKER_ENDPOINT}/v2/keys/cassandra/seeds -d value="${NEW_SEEDS}" 2>/dev/null
    fi
fi

echo "Listening on: "$IP
echo "Found seeds: "$SEEDS

CONFIG=/etc/cassandra/
sed -i -e "s/^cluster_name.*/cluster_name: ${CLUSTER_NAME}/"            $CONFIG/cassandra.yaml
sed -i -e "s/^listen_address.*/listen_address: $IP/"            $CONFIG/cassandra.yaml
sed -i -e "s/^rpc_address.*/rpc_address: $IP/"              $CONFIG/cassandra.yaml
sed -i -e "s/- seeds: \"127.0.0.1\"/- seeds: \"$SEEDS\"/"       $CONFIG/cassandra.yaml
sed -i -e "s/# JVM_OPTS=\"$JVM_OPTS -Djava.rmi.server.hostname=<public name>\"/ JVM_OPTS=\"$JVM_OPTS -Djava.rmi.server.hostname=$IP\"/" $CONFIG/cassandra-env.sh

# Start Cassandra
echo Starting Cassandra...
cassandra -f -p /var/run/cassandra.pid
