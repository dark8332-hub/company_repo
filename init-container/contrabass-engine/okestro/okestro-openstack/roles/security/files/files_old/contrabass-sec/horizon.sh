# ifram
check_ifram_disallow=$(cat /etc/openstack-dashboard/local_settings.py | grep DISALLOW_IFRAME_EMBED)
ifram_flag=$(cat /etc/openstack-dashboard/local_settings.py | grep DISALLOW_IFRAME_EMBED | awk -F'=' '{print $2}')

sed -i "s/#HORIZON_CONFIG\[\"password_autocomplete\"\] = \"off\"/HORIZON_CONFIG\[\"password_autocomplete\"\] = \"off\"/g" /etc/openstack-dashboard/local_settings.py
sed -i "s/#HORIZON_CONFIG\[\"disable_password_reveal\"\] = False/HORIZON_CONFIG\[\"disable_password_reveal\"\] = True/g" /etc/openstack-dashboard/local_settings.py
sed -i "s/#SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')/SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')/g" /etc/openstack-dashboard/local_settings.py

if [[ "$check_ifram_disallow" == "" ]];
then
  echo "DISALLOW_IFRAME_EMBED = True" >> /etc/openstack-dashboard/local_settings.py
elif [[ "$ifram_flag" == *"True"* ]];
then
  echo "EMBED PASS"
else
  iflag=$(echo $check_ifram_disallow)
  sed -i "s/$iflag/DISALLOW_IFRAME_EMBED = True/g" /etc/openstack-dashboard/local_settings.py
fi
  

# enforce
check_enforce=$(cat /etc/openstack-dashboard/local_settings.py | grep ENFORCE_PASSWORD_CHECK)
enforce_flag=$(cat /etc/openstack-dashboard/local_settings.py | grep ENFORCE_PASSWORD_CHECK | awk -F'=' '{print $2}')

if [[ "$check_enforce" == "" ]];
then
  echo "ENFORCE_PASSWORD_CHECK = True" >> /etc/openstack-dashboard/local_settings.py
elif [[ "$enforce_flag" == *"True"* ]];
then
  echo "ENFORCE PASS"
else
  eflag=$(echo $check_enforce)
  sed -i "s/$eflag/ENFORCE_PASSWORD_CHECK = True/g" /etc/openstack-dashboard/local_settings.py
fi
