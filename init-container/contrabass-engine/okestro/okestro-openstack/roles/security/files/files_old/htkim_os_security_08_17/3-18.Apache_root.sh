apache_check=$(ps -ef | grep apache | grep -v grep)
#cat /etc/apache2/apache2.conf | grep -w Options | grep Indexes | grep -Ev '^#|#Options Indexes' | while read line
root_check=$(cat /etc/apache2/apache2.conf | grep -E '^User|^Group' | awk '{print $2}')

if [[ "$apache_check" == "" ]];
then
     	echo -e "\033[0;32mApache Not use \033[0m"
else
	for i in $root_check
	do
		if [[ "$i" == "root" ]];
		then
		        echo -e "\033[0;31m use root process BAD!! \033[0m"
			echo "use root process in /etc/apache2/apache2.conf" >> un_change_list.txt
			echo "Please change process to not root user " >> un_change_list.txt
		else
		        echo -e "\033[0;32m Not use root process GOOD!! \033[0m"
		fi
	done
fi
