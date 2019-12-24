#!/bin/bash
# change seeds to switch cluster mode to 
# one unify cluster across 2 regions 
# or 2 seprated clusters

#set -e

function usage(){
    echo " Usage: $0 <onecluster|jpeast|jpwest>"
    echo " - onecluster : joining current node into one cluster even these nodes are in different regions"
    echo " - jpeast : joining current node into separated cluster located in JP EAST"
    echo " - jpwest : joining current node into separated cluster located in JP WEST"
    exit 1
}

if [ $# -ne 1 ]; then
    echo " -- one parameter is required."
    usage
fi

case $1 in
    onecluster)
        # seeds are west02 & west03
        SEEDS="100.18.0.7,100.18.0.8"
        CLUSTER_NAME="simba-cassandra"
        ;;
    jpeast)
        # seeds are east02 & east03
        SEEDS="100.19.0.5,100.19.0.6"
        CLUSTER_NAME="simba-cassandra-east"
        ;;
    jpwest)
        # seeds are west02 & west03
        SEEDS="100.18.0.7,100.18.0.8"
        CLUSTER_NAME="simba-cassandra"
        ;;
    *)
        echo " -- $1 is not supported"
        usage
esac

# remove node from cassandra ring
echo ' -- remove node from cassandra ring'
nodetool decommission

# stop cassandra DB
echo ' -- stop cassandra DB'
systemctl stop cassandra

# remove cassandra data
echo ' -- remove cassandra data /var/lib/cassandra/*'
rm -rf /var/lib/cassandra/*

# replace SEED based on cluster purpose
echo " -- replace SEED to $1 - ${SEEDS}"
sed -i.$(date +"%Y%m%d%H%M%S") "/^[^#]/s/seeds:.*$/seeds: \"${SEEDS}\"/" /etc/cassandra/conf/cassandra.yaml

# replace cluster name based on region name
echo " -- replace cluster name to ${CLUSTER_NAME}"
sed -i.$(date +"%Y%m%d%H%M%S") "s/^cluster_name:.*$/cluster_name: \'${CLUSTER_NAME}\'/" /etc/cassandra/conf/cassandra.yaml

# restart cassandra DB
echo ' -- restart cassandra DB'
systemctl start cassandra && systemctl status cassandra
