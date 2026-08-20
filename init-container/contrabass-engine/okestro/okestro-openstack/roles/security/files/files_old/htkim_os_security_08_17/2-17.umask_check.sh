UMASK=$(umask)
file=/etc/profile
PROFILE_UMASK=$(cat $file | grep umask | awk '{print $2}')
UMASK_CHECK=$(cat $file | grep -h '^umask')

if [[ "$UMASK" == "0022" ]];
then
        echo -e "\033[0;32mUMASK GOOD!! \033[0m"
else 

	if [[ "$UMASK_CHECK" == "" ]];
	then
	        echo -e "\033[0;31mUMASK Not Exist \033[0m"
	        echo -e "\033[0;31mAdd Umask in $file \033[0m"
		echo umask 022 >> $file
	else
		if [[ "$PROFILE_UMASK" == "022" ]];
		then
        		echo -e "\033[0;32mUMASK GOOD!! \033[0m"
			source $file
		else
		        echo -e "\033[0;31mUMASK $PROFILE_UMASK!! change UMASK to 022\033[0m"
	      		echo -e "UMASK $PROFILE_UMASK!! change UMASK to 022" >> change_list.txt
			sed -i "/umask/ s/umask $PROFILE_UMASK/umask 022/g" $file
			source $file
		fi

	fi
fi
