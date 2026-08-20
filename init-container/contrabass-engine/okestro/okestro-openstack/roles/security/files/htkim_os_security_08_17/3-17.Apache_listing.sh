apache_dir_check=$(cat /etc/apache2/apache2.conf | grep -w Options | grep Indexes | grep -Ev '^#|#Options Indexes')
apache_check=$(ps -ef | grep apache | grep -v grep)
#cat /etc/apache2/apache2.conf | grep -w Options | grep Indexes | grep -Ev '^#|#Options Indexes' | while read line

if [[ "$apache_check" == "" ]];
then
     	echo -e "\033[0;32mApache Not use \033[0m"
else
	echo $apache_dir_check | while read line
	do
		if [[ "$line" == "" ]];
		then
	       		 echo -e "\033[0;32mApache Directory listing GOOD!! \033[0m"
		else
	        	echo -e "\033[0;31mApache Directory listing Use BAD!! \033[0m"
	        	echo -e "Apache Directory listing Use BAD!!"  >> change_list.txt
			sed -i "s/$line/#$line/g" /etc/apache2/apache2.conf
			systemctl restart apache2
	        	echo  "Change /etc/apache2/apache2.conf unannotation "  >> change_list.txt
		fi
	done
fi
