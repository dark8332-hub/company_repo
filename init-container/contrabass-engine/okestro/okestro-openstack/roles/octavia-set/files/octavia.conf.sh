#!/bin/bash

source /root/contrabass-openrc

lb_net=$(openstack network show lb-mgmt-net -c id -f value)
lb_sec=$(openstack security group show lb-mgmt-sec-grp -c id -f value)

sed -i "s/^amp_boot_network_list.*/amp_boot_network_list = $lb_net/" /etc/octavia/octavia.conf
sed -i "s/^amp_secgroup_list.*/amp_secgroup_list = $lb_sec/" /etc/octavia/octavia.conf

systemctl restart octavia-api octavia-health-manager octavia-housekeeping octavia-worker
