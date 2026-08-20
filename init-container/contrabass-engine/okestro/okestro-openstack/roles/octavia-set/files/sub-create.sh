#!/bin/bash
OCTAVIA_MGMT_SUBNET=172.16.0.0/22
OCTAVIA_MGMT_SUBNET_START=172.16.0.100
OCTAVIA_MGMT_SUBNET_END=172.16.2.254

OCTAVIA_MGMT_PORT_IP={{ octavia_health_manager_ip }}
OCTAVIA_HEALTH_MANAGER_PORT_NAME={{ octavia_health_manager_port_name }}

source /root/contrabass-openrc

SUBNET_ID=$(openstack subnet show lb-mgmt-subnet -f value -c id)
PORT_FIXED_IP="--fixed-ip subnet=$SUBNET_ID,ip-address=$OCTAVIA_MGMT_PORT_IP"

MGMT_PORT=$(openstack port list | grep $OCTAVIA_HEALTH_MANAGER_PORT_NAME)

if [ -n "$MGMT_PORT" ]
then
    MGMT_PORT_MAC=$(openstack port show -c mac_address -f value $OCTAVIA_HEALTH_MANAGER_PORT_NAME)
    MGMT_PORT_ID=$(openstack port show -c id -f value $OCTAVIA_HEALTH_MANAGER_PORT_NAME)
else
    MGMT_PORT_ID=$(openstack port create --security-group {{H_SECURITY_GROUP_NAME}} --device-owner octavia:health-mgr \
     --host=$(hostname) -c id -f value --network {{OCTAVIA_NETWORK_NAME}} \
    $PORT_FIXED_IP $OCTAVIA_HEALTH_MANAGER_PORT_NAME)
    MGMT_PORT_MAC=$(openstack port show -c mac_address -f value \
    $MGMT_PORT_ID)
fi

NETID=$(openstack network show {{OCTAVIA_NETWORK_NAME}} -c id -f value)
OVS_PORT=$(ovs-vsctl show | grep hm0)

if [ -n "$OVS_PORT" ]
then
    sleep 1
else
    ovs-vsctl add-port br-int o-hm0 \
    -- set Interface o-hm0 type=internal \
    -- set Interface o-hm0 external-ids:iface-status=active \
    -- set Interface o-hm0 external-ids:attached-mac=$MGMT_PORT_MAC \
    -- set Interface o-hm0 external-ids:iface-id=$MGMT_PORT_ID
fi

sudo ip link set dev o-hm0 address $MGMT_PORT_MAC
sudo iptables -I INPUT -i o-hm0 -p udp --dport 5555 -j ACCEPT
sudo dhclient -v o-hm0

if [ -n "$(ip route show default | grep 172.16.0.1)" ]
then
sudo ip route del default via 172.16.0.1 dev o-hm0
else
    sleep 1
fi
