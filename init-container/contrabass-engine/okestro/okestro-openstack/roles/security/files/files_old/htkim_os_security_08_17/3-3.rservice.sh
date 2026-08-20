#rservice=$(ls -alL /etc/xinetd.d/* | egrep "rsh|rlogin|rexec" | grep -v "grep |klogin | kshell | kexec")

ls -alL /etc/xinetd.d/* | egrep "rsh|rlogin|rexec" | grep -v "grep |klogin | kshell | kexec" | while read line
do
	if [[ $line == "" ]];
	then
	        echo -e "\033[0;32mNot Exsit r Service \033[0m"
	else
		rservice_name=$(echo $line | awk '{print $NF}')
		used_check=$(cat $rservice_name | grep 'disable' | awk '{print $3}')
		if [[ "$used_check" == "yes" ]];
		then
	        	echo -e "\033[0;32m$rservice_name is Not use r Service \033[0m"
		elif [[ "$used_check" == "" ]];
		then
			none_file=$(cat $rservice_name)
			if [[ "$none_file" == "" ]];
			then
	        		echo -e "\033[0;32m$rservice_name is empty \033[0m"
			else
				echo -e "$rservice_name file strange content \n $none_file" >> change_list.txt
	        		echo -e "\033[0;31m$rservice_name file strange content!! \033[0m"
			fi
		else
	        	echo -e "\033[0;31mUse $rservice_name Service \033[0m"
	        	echo "Use $rservice_name Service" >> change_list.txt
	        	echo "Use $rservice_name change Disable" >> change_list.txt

			sed -i "/disable/ s/= .*$/= yes/g" $rservice_name
			systemctl restart xinetd
		fi
	fi
done


