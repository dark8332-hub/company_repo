not_device_list=$(find /dev -type f -exec ls -l {} \; | awk '{print $NF}')


if [[ $not_device_list == "" ]];
then
	echo -e "\033[0;32mState Good!! \033[0m"
else
	echo -e "\033[0;31mNo Device List!! \033[0m"
	for i in $not_device_list
	do
		echo $i
		echo $i >> change_list.txt
		rm -rf $i
       		echo "Remove $i" >> change_list.txt
	done
fi
