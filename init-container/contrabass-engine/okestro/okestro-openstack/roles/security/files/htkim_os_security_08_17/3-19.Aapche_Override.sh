apache_check=$(ps -ef | grep apache | grep -v grep)
apache_override=$(cat /etc/apache2/apache2.conf | grep 'AllowOverride' | grep -hv '^#' | awk '{print $2}')


if [[ "$apache_check" == "" ]];
then
     	echo -e "\033[0;32mApache Not use \033[0m"
else
	for i in $apache_override
	do
		if [[ "$i" == "None" ]];
		then
		        echo -e "\033[0;31mApache AllowOverride BAD!! \033[0m"
		        echo -e "Apache AllowOverride to AuthConfig in /etc/apache2/apache2.conf" >> change_list.txt
			sed -i "s/AllowOverride $i/AllowOverride AuthConfig/g" /etc/apache2/apache2.conf
			systemctl restart apache2
		else
		        echo -e "\033[0;32mApache AllowOverride GOOD!! \033[0m"
		fi
	done	

fi
