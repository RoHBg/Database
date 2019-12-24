#!/bin/bash

#set -e

function usage(){
    echo " Usage: $0 <jpeast|jpwest>"
    echo " - jpeast : joining current node into separated cluster located in JP EAST"
    echo " - jpwest : joining current node into separated cluster located in JP WEST"
    exit 1
}

if [ $# -ne 1 ]; then
    echo " -- one parameter is required."
    usage
fi

# vars defination
#CLUSTER_NAME="simba-cassandra"
PRIVATE_IP="$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | awk -F'/' '{print $1}')"
#DC="jp-west"
#SEEDS="100.18.0.7,100.18.0.8"
RACK='rack1'
DATA_DIR="/var/lib/cassandra"
CASS_CONF="/etc/cassandra/conf/cassandra.yaml"
RACKDC_CONF="/etc/cassandra/conf/cassandra-rackdc.properties"

# generate yum repo file
echo ' -- create yum repo file'
cat << EOF > /etc/yum.repos.d/cassandra.repo
[cassandra]
name=Apache Cassandra
baseurl=https://www.apache.org/dist/cassandra/redhat/311x/
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://www.apache.org/dist/cassandra/KEYS
EOF

# install Cassandra
echo ' -- start isntalling Cassandra'
yum install -y cassandra

# generate systemd service file
echo ' -- generate systemd service file'
cat << EOF > /etc/systemd/system/cassandra.service
[Unit]
Description=Apache Cassandra
After=network.target

[Service]
PIDFile=/var/run/cassandra/cassandra.pid
User=cassandra
Group=cassandra
ExecStart=/usr/sbin/cassandra -f -p /var/run/cassandra/cassandra.pid
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# reload service defination
echo ' -- reloas systemd service defination'
systemctl daemon-reload

# enable auto startup after reboot
echo ' -- enable cassandra auto start'
systemctl enable cassandra

# config vg,lv,datastore for Cassandra
echo ' -- start configuing datastore for Cassandra'
systemctl stop cassandra
vgcreate datavg /dev/sdc 
lvcreate --name datalv -l100%FREE datavg
mkfs.xfs /dev/mapper/datavg-datalv 
echo '/dev/mapper/datavg-datalv /data                                   xfs     defaults        0 0' >> /etc/fstab
cd /var/lib/ && mv cassandra cassandra.bak
mkdir /data && mount -a && mkdir /data/cassandra && chown cassandra.cassandra /data/cassandra
ln -s /data/cassandra /var/lib/cassandra
mv /var/lib/cassandra.bak/* /data/cassandra/

case $1 in
    jpeast)
        # seeds are east02 & east03
        SEEDS="100.19.0.5,100.19.0.6"
        CLUSTER_NAME="simba-cassandra-east"
        DC="jp-east"
        ;;
    jpwest)
        # seeds are west02 & west03
        SEEDS="100.18.0.7,100.18.0.8"
        CLUSTER_NAME="simba-cassandra-west"
        DC="jp-west"
        ;;
    *)
        echo " -- $1 is not supported"
        usage
esac

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
