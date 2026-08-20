chmod 640 /etc/nova/nova.conf
chmod 640 /etc/cinder/cinder.conf
chmod 640 /etc/glance/glance-api.conf
chmod 640 /etc/manila/manila.conf
chmod 640 /etc/neutron/neutron.conf

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
systemctl restart nova-*

# cinder
cinder_keystone_sec=$(sed -n '/\[keystone_authtoken\]/, /^\[/p' /etc/cinder/cinder.conf | grep insecure)

if [[ $cinder_keystone_sec == "" ]];
then 
  sed -i -r -e "/keystone_authtoken/a\insecure = false" /etc/cinder/cinder.conf
elif [[ $cinder_keystone_sec == *"#"* ]];
then
  sed -i '/insecure/ s/^.//' /etc/cinder/cinder.conf
fi 

cinder_default_sec=$(sed -n '/\[DEFAULT\]/, /^\[/p' /etc/cinder/cinder.conf | grep glance_api_insecure)
if [[ $cinder_default_sec == "" ]];
then 
  sed -i -r -e "/DEFAULT/a\glance_api_insecure = false" /etc/cinder/cinder.conf
elif [[ $cinder_default_sec == *"#"* ]];
then
  sed -i '/glance_api_insecure/ s/^.//' /etc/cinder/cinder.conf
fi 

cinder_oslo_middle_section_check=$(cat /etc/cinder/cinder.conf | grep "\[oslo_middleware\]")
if [[ $(echo $cinder_oslo_middle_section_check) == "" ]];
then
  echo -e "[oslo_middleware]\nmax_request_body_size = 114688" >> /etc/cinder/cinder.conf
else
  cinder_oslo_middle_section_check=$(sed -n '/\[oslo_middleware\]/, /^\[/p' /etc/cinder/cinder.conf | grep "max_request_body_size")
  if [[ "$cinder_oslo_middle_section_check" == "" ]];
  then
  sed -i -r -e "/\[oslo_middleware\]/a\max_request_body_size = 114688" /etc/cinder/cinder.conf
  echo 123123
  fi
fi
systemctl restart  cinder-volume cinder-scheduler

# glance
glance_keystone_sec=$(sed -n '/\[keystone_authtoken\]/, /^\[/p' /etc/glance/glance-api.conf | grep insecure)

if [[ $glance_keystone_sec == "" ]];
then 
  sed -i -r -e "/keystone_authtoken/a\insecure = false" /etc/glance/glance-api.conf
elif [[ $glance_keystone_sec == *"#"* ]];
then
  sed -i '/insecure/ s/^.//' /etc/glance/glance-api.conf
fi 
systemctl restart glance-api


# manila
manila_keystone_sec=$(sed -n '/\[keystone_authtoken\]/, /^\[/p' /etc/manila/manila.conf | grep insecure)

if [[ $manila_keystone_sec == "" ]];
then 
  sed -i -r -e "/keystone_authtoken/a\insecure = false" /etc/manila/manila.conf
elif [[ $manila_keystone_sec == *"#"* ]];
then
  sed -i '/insecure/ s/^.//' /etc/manila/manila.conf
fi 


manila_nova_sec=$(sed -n '/\[nova\]/, /^\[/p' /etc/manila/manila.conf | grep insecure)
if [[ $manila_nova_sec == "" ]];
then 
  sed -i -r -e "/\[nova\]/a\insecure = false" /etc/manila/manila.conf
elif [[ $manila_nova_sec == *"#"* ]];
then
  sed -i '/insecure/ s/^.//' /etc/manila/manila.conf
fi


manila_neutron_sec=$(sed -n '/\[neutron\]/, /^\[/p' /etc/manila/manila.conf | grep insecure)
if [[ $manila_neutron_sec == "" ]];
then 
  sed -i -r -e "/\[neutron\]/a\insecure = false" /etc/manila/manila.conf
elif [[ $manila_neutron_sec == *"#"* ]];
then
  sed -i '/insecure/ s/^.//' /etc/manila/manilaconf
fi

manila_oslo_middle_section_check=$(cat /etc/manila/manila.conf | grep "\[oslo_middleware\]")
if [[ $(echo $manila_oslo_middle_section_check) == "" ]];
then
  echo -e "[oslo_middleware]\nmax_request_body_size = 114688" >> /etc/manila/manila.conf
else
  manila_oslo_middle_section_check=$(sed -n '/\[oslo_middleware\]/, /^\[/p' /etc/manila/manila.conf | grep "max_request_body_size")
  if [[ "$manila_oslo_middle_section_check" == "" ]];
  then
  sed -i -r -e "/\[oslo_middleware\]/a\max_request_body_size = 114688" /etc/manila/manila.conf
  fi
fi


systemctl restart manila-api manila-scheduler

neutron_keystone_sec=$(sed -n '/\[keystone_authtoken\]/, /^\[/p' /etc/neutron/neutron.conf | grep insecure)
if [[ $neutron_keystone_sec == "" ]];
then 
  sed -i -r -e "/\[keystone_authtoken\]/a\insecure = false" /etc/neutron/neutron.conf
elif [[ $neutron_keystone_sec == *"#"* ]];
then
  sed -i '/insecure/ s/^.//' /etc/neutron/neutron.conf
fi
systemctl restart neutron-server neutron-dhcp-agent neutron-metadata-agent neutron-l3-agent neutron-openvswitch-agent

sed -i "s/#max_request_body_size = 114688/max_request_body_size = 114688/g" /etc/keystone/keystone.conf
sed -i "s/#admin_token = <None>/admin_token = None/g" /etc/keystone/keystone.conf

systemctl restart apache2
