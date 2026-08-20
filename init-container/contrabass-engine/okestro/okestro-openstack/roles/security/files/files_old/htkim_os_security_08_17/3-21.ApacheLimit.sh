apache_check=$(ps -ef | grep apache | grep -v grep)
file=/etc/apache2/apache2.conf
#limit=$(cat $file | grep LimitRequestBody grep -Ev "^#|#LimitRequestBody")
limit_size=$(cat $file | grep LimitRequestBody | awk '{print $2}')
check=$(cat $file | sed -n "/<Directory/,/Directory>/p" | grep 'LimitRequestBody')

if [[ "$apache_check" == "" ]];
then
     	echo -e "\033[0;32mApache Not use \033[0m"
else
	if [[ "$check" == "" ]];
	then
	        echo -e "\033[0;31mLimitRequestBody Not Found BAD!! \033[0m"
	        echo -e "LimitRequestBody Not Found BAD!!" >> change_list.txt
		sed -i'' -r -e "/^<Directory/a\	LimitRequestBody 5000000" $file
		echo "Service Apache restarting...."
		systemctl restart apache2
	else
		for i in $limit_size
		do
			if [[ "$i" -ge "5000000" ]];
			then
	        		echo -e "\033[0;32mLimitRequestBody size $i GOOD !! \033[0m"
			else
	        		echo -e "\033[0;31mLimitRequestBody size $i BAD !! \033[0m"
	        		echo -e "LimitRequestBody size $i BAD !!" >> change_list.txt
				sed -i "/LimitRequestBody size/s/$i/5000000/g" $file
				echo "LimitRequestBody size change 5000000" >> change_list.txt
				echo "Service Apache restarting...."
				systemctl restart apache2
			fi
		done
	fi

fi



