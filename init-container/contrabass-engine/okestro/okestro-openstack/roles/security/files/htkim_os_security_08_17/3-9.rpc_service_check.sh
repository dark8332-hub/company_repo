#rpc_servicelist=$(ls -alL /etc/xinetd.d/* )


ls -laL /etc/xinetd.d/* | awk  '{print $NF}' | while read line
do
	#echo $line
	service_check=$(cat $line | grep 'disable' | awk '{print $NF}')
	for i in $service_check
	do
		if [[ "$i" == "yes" ]];
		then
			service_list=$(echo $line | awk -F/ '{print $NF}')
			echo -e "\033[0;32m$service_list not use \033[0m"
		else
			service_list=$(echo $line | awk -F/ '{print $NF}')
			echo -e "\033[0;31m$service_list use \033[0m"
			echo -e "$service_list use" >> un_change_list.txt
		fi
	done
	
done
