apache_check=$(ps -ef | grep apache | grep -v grep)
apache_link=$(cat /etc/apache2/apache2.conf | grep 'FollowSymLinks' | grep -Ev '^#|#Options.*.FollowSymLinks$' | awk '{print $NF}')


if [[ "$apache_check" == "" ]];
then
     	echo -e "\033[0;32mApache Not use \033[0m"
else
	for i in $apache_link
	do
		if [[ "$i" == "FollowSymLinks" ]];
		then
		        echo -e "\033[0;31mApache Links BAD!! \033[0m"
		        echo -e "Apache Links change $i annotaion line /etc/apache2/apache2.conf" >> change_list.txt
			sed -i "/$i/ s/Options/#Options/g" /etc/apache2/apache2.conf
			systemctl restart apache2
		else
		        echo -e "\033[0;32mApache FolowSymLinks GOOD!! \033[0m"
		fi
	done	

fi



