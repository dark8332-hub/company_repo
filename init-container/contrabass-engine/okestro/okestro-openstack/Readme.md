# Contrabass openstack deploy ansible

<hr/>

## 변경사항


	1. 24/04/09 - First Commit & cinder.keyring Copy To Compute Node 
	2. 24/04/11 - Octavia-set Main.yml Fix
	3. 24/04/12 - Octavia Main.yml Annotation Remove
	4. 24/04/15 - Fix Disabling Firewall
	5. 24/04/16 - Fix Manila https python code, Fix Masakari for compute host in controller group, Fix octavia-interface.sh.j2, 
	              Fix Ceph Keyring Copy
	6. 24/04/17 - Fix masakari-dashboard.sh.j2, Fix openstack-dashboard.conf.j2
	7. 24/04/18 - Fix Purge & Add Delete libvirt user
	8. 24/04/19 - OpenStack Upgrade (Wallaby -> Yoga) Ansible Add
	9. 24/04/22 - Add tls migration
	10. 24/04/23 - Fix placement-init.yml, Octavia-interface-daemon Fix,
	               Add Purge Compute Node, Masakari Public Endpoint Create Fix
	11. 24/04/24 - Fix Masakari Dashboard Yoga Version Installation by manual to package, 
	               Add Octavia-set cloud.yml.j2 verify option, Add Masakari masakari-dashboard.yml 
	               apache daemon restart, Modify masakari task masakari-dashboard.yml 
	               typo and certificates tasks main.yml, generate-server.yml, 
	               Fix pakage_ip -> package_ip, Change Ceph & main.yml, 
	               Fix Certificate check.yml task comment out, Fix local.repo.j2, Fix main.yml task, 
	               Modify Manila directory default to defaults, Fix main.yml swift role
	12. 24/04/25 - Fix Prometheus Role, Add inventory/group_vars/all/main.yml 
	               RadosGW Interface Value, Modify Swift HAProxy Setting Task
	13. 24/04/26 - Modify okestro-openstack main.yml prometheus hosts storage to radosgw, 
	               Modify prometheus task main.yml radosgw-user-setting host group storage to radosgw, 
	               Delete prometheus task radosgw-user-setting haproxy setting, 
	               Add prometheus task s3cmd-install haproxy radosgw setting, 
	               Delete octavia-set task octavia-basic-set.yml Upload amphora image when ceph
	13. 24/04/29 - Modify purge ansible libvirt-dnsmasq user delete task 'remove: true' del
	14. 24/05/07 - Add tls migration role, Delete certificate role with tls migration, 
	               Add main.yml task with tls migration, Manila TLS Python Code Modify, 
	               Delete certificate role with main task check-certificate, 
	               Add tls-migration role with never-delete.txt file
	15. 24/05/08 - Fix prometheus role with templates prometheus.yml.j2 and monitoring-server.conf.j2, 
	               Manila Code Fix, TLS-Migration For enable_openstack_tls, 
	               Fix Heat-init Error Code, Fix tls-migration role with template directory, 
	               Add New-compute addnode.yml Task File & Roles
	               Add Haproxy Configuration Check Logic
	16. 24/05/09 - Add aditional Manila task about connet with Ceph Cluster, Fix Add Node Tasks,
	               Fix Masakarimonitor Task to Restarting, Fix Addnode role
	17. 24/08/07 - Integration of Ceph-Ansible and Okestro-Openstack-Ansible
	               Remove some tasks to improve deployment speed
	               Modify self-signed certificate
	               Modify heat https endpoint support
	               Add domain endpoint and https support
	               Remove some group_vars variables
	               Add all-in-one model contrabass portal & contrabass mole deployment
	               Modify TLS support when 'enable_openstack_tls: false' to do not ensure TLS
	               Add SSH Key exchange automatically to don't need ssh-copy-id before play
	               Modify playbook tags
	18.	24/08/08 - Modify ceph config copy
	19.	24/08/09 - Modify swift endpoint
	20.	24/08/12 - Modify swift && cinder volume restart tasks, cinder-volume clustering && remove single volume backend binaries, Modify variables 
	21.	24/08/23 - Add Heat config memcached_servers option
	22.	24/09/05 - Hot Fix Chrony.conf
	23.	24/11/21 - Fix thanos storage option and tls options, Fix nova-novnc haproxy setting
		           Delete manila-share restart task before set share backend, Fix SSL message excessive size error
	24.	24/11/22 - Fix prometheus main task typo, Add Install Barbican , Fix- Fedora OS SSL Authentication Error
		           Remove unused amphora image
	25.	24/11/25 - Fix thanos task and template to run normally, Modify contrabass-mole TLS set
	26.	24/11/27 - Fix contrabass-mole TLS set typo
	27.	24/12/02 - Fix monitoring ha enable conditional statement
	29.	24/12/30 - Fix Fedora OS Contrabass Ansible Compatibility Update
		           Modify ceph-volume on Fedora OS
		           Modify Percona,Keystone,Glance,Compute below Rhel 9 to not execute module disable 
		           Modify Chrony Hnadler
		           Modify Rabbitmq LimitNOFILE=65535 Add setting values
		           Modify pac_wsgi : mod_wsgi -> python3-mod_wsgi in all.yml
		           Add cinder-api restart to cinder task
		           Change Horizon task config file setting group to global var
	30.	25/02/12 - Add Contrabass & Viola Instnace Creation Funtion , Fix - Octavia.conf
		           Add Funtion Create Instance of Contrabass & Viola
		           Modify octavia.conf "controller_ip_port_list" option
		           Add delete cert on Certificate Task
		           Cinder backend Naming rule definition
	31.	25/02/17 - Fix v1.5.0 Contrabass-Ansible
		           Delete cert on Certificate Task
		           Fix Rabbitmq Task config.yml
		           Fix cinder-api start Task
	32.	25/02/26 - Fix v1.5.1 Contrabass-Ansible
		           Add Rabbitmq durable & notifications config
		           Fix Octavia Interface Network band Change
	33.	25/02/27 - Add rabbitmq admin user & administrator tags to admin,openstack user
		           Add internal_vip_subnet(24cidr) privileges to mysql root user
		           Modify contrabass mole installation, Add mole config file
		           Add impi user, password vars & snmp,lldpd package for contrabass mole
	34.	25/03/06 - Update Contrabass-mole binary
	35.	25/03/07 - Disable amqp durable options
	36.	25/03/28 - Update contrabass-mole.tar.gz
	37.	25/04/04 - Update Add node, Modify Certificates, Delete TLS-Migration role
	38.	25/04/07 - Fix hard coded 'cloud1234' password to {{ keystone_pass }}
	39.	25/04/09 - Change branch to portal version: v1.5 -> v3.0.3
	40.	25/06/11 - Upgrade version v3.0.4, implement openstack-caracal + Suse 9.4 or openstack-caracal + Ubuntu 24.04,
		           Add MinIO installation, Change ceph-ansible to cephadm deployment, Add Exporters installation,
		           Integration Thanos/Loki with MinIO object storage, Upgrade addnode ansible
	41.	25/06/16 - Update openstack-exporter
	42.	25/06/27 - Update Tech-preview role/tasks, Mole 3.0.4
	43.	25/07/01 - Hot fix contrabass-mole 3.0.4
	44.	25/07/11 - Update amphora image yoga to caracal & Fixing octavia python code
	45.	25/07/15 - Fix prometheus contrabass-mole job name
	46.	25/07/29 - Update Suse 9.4 pacemaker repository for masakari
	47.	25/08/14 - Refine MinIO attachment logic & Create backup bucket
		           Update MinIO/Percona deployment for all-in-one model
		           Fix addnode
		           Update Contrabass-mole 07/25 & Integrate MinIO as a backup storage
	48.	25/08/18 - Fix compute role neutron template interpolation && Change Masakari monitoring interval 60 -> 10
		           Update OVS port mapping to apply VLAN tag
		           Update MinIO HAproxy options
		           Update cinder configuration noitification_driver -> driver
	49.	25/08/20 - Update Ceph deploy device name to device path
		           Add ceph integration rbd pool initialize
	50.	25/09/01 - Hotfix typo mysql configuration
	51.	25/09/17 - Update RabbitMQ Version to 4.1.2 for CVE
		           Update contrabass-mole
	52.	25/10/14 - Update contrabass-mole
	53.	25/10/20 - Update Ceph HAproxy Config & Workaround for a few bugs
	   	           Update Ceph Exporter
	   	           Fix ceph-cluster.yaml.j2 File 
	54.	25/10/27 - Update os_brick Patch for Caracl Version
	55.	25/10/29 - Update IPMI Exporter systemd unit to use correct executable path
	56.	25/11/03 - Update Mole version 3.0.4 to 3.0.4.22 & Integrate Prometheus configuration with Mole exporter
	57.	25/11/04 - Fix Mole config file duplicate exporter bind port
	58.	25/12/08 - Update contrabass-mole (12/05)
	59.	25/12/09 - Update os-brick to compute roles
	60.	25/12/10 - Update loki.service file
