#!/bin/bash

set -e

# vars defination
CLUSTER_NAME="simba-cassandra"
PRIVATE_IP="$(ifconfig eth0 | grep 'inet ' | awk '{print $2}')"
DC="jp-west"
SEEDS="100.18.0.7,100.18.0.8"
RACK='rack1'
DATA_DIR="/var/lib/cassandra"
CASS_CONF="/etc/cassandra/conf/cassandra.yaml"
RACKDC_CONF="/etc/cassandra/conf/cassandra-rackdc.properties"

# delete node from cluster ring
echo ' -- remove node from cassandra ring'
#nodetool decommission

# stop cassandra
echo ' -- stop cassandra DB'
systemctl stop cassandra

# backup conf file
echo ' -- backup configutaion files'
cp ${CASS_CONF} ${CASS_CONF}.$(date +"%Y%m%d%H%M%S")
cp ${RACKDC_CONF} ${RACKDC_CONF}.$(date +"%Y%m%d%H%M%S")

# remove data commit log and caches
echo ' -- remove cassandra data /var/lib/cassandra/*'
rm -rf ${DATA_DIR}/commitlog
rm -rf ${DATA_DIR}/data
rm -rf ${DATA_DIR}/saved_caches

# applying configuration
echo ' -- applying configuration'
sed -i "s/^listen_address: localhost/listen_address: ${PRIVATE_IP}/" ${CASS_CONF}
sed -i "s/^rpc_address: localhost/rpc_address: ${PRIVATE_IP}/" ${CASS_CONF}
sed -i "/^[^#]/s/seeds:.*$/seeds: ${SEEDS}/" ${CASS_CONF}
sed -i "s/^cluster_name:.*$/cluster_name: ${CLUSTER_NAME}/" ${CASS_CONF}
sed -i "s/^dc=.*$/dc=${DC}/" ${RACKDC_CONF}
sed -i "s/^rack=.*$/rack=${RACK}/" ${RACKDC_CONF}

# start CassandraDB
echo ' -- restart cassandra DB'
systemctl start cassandra && systemctl status cassandra
