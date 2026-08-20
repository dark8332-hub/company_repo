echo "####################################### 증적자료 제출 목록 ########################################
 ### nova  ls -la /etc/nova/ ###
ls -la /etc/nova/
 ### cinder  ls -la /etc/cinder/ ###
ls -la /etc/cinder
 ### glance  ls -la /etc/glance/ ###
ls -la /etc/glance
 ### manila  ls -la /etc/manila/ ###
ls -la /etc/manila
 ### neutron  ls -la /etc/neutron/ ###
ls -la /etc/neutron

### hash_algorithm sha256
      해당 버전은 yoga ###

### Nova.conf [glance] section에 api_insecure 옵션이 존재하지 않음 증적 url: https://docs.openstack.org/nova/yoga/configuration/sample-config.html ###

1. manila.conf [keystone_authtoken] section에 auth_protocol, identity_uri존재하지 않고 www_authenticate_uri는 존재하므로 https 설정>이 되어있음.
2. nova_api_insecure 매개변수는 존재하지않고 [nova]section이 존재 [nova] section에 insecure 설정
3. neutron_api_insecure 매개변수는 존재하지않고 [neutron]section이 존재 [neutron] section에 insecure 설정

neturon use_ssl은 ssl api를 사용한다는 뜻인데 해당에선 api endpoint를 https로 사용하고있음 ###

yoga version에서는 auth_strategy 설정이 존재하지 않음 증적자료: https://docs.openstack.org/glance/yoga/configuration/glance_api.html

##################################################################################################" >> evidence.txt


# nova
nova_keystone_sec=$(sed -n '/\[keystone_authtoken\]/, /^\[/p' /etc/nova/nova.conf | grep insecure)

if [[ $nova_keystone_sec == "" ]];
then 
  sed -i -r -e "/keystone_authtoken/a\insecure = false" /etc/nova/nova.conf
elif [[ $nova_keystone_sec == *"#"* ]];
then
  sed -i '/insecure/ s/^.//' /etc/nova/nova.conf
fi 
systemctl restart nova-compute

neutron_keystone_sec=$(sed -n '/\[keystone_authtoken\]/, /^\[/p' /etc/neutron/neutron.conf | grep insecure)
if [[ $neutron_keystone_sec == "" ]];
then 
  sed -i -r -e "/\[keystone_authtoken\]/a\insecure = false" /etc/neutron/neutron.conf
elif [[ $neutron_keystone_sec == *"#"* ]];
then
  sed -i '/insecure/ s/^.//' /etc/neutron/neutron.conf
fi
systemctl restart neutron-openvswitch-agent
