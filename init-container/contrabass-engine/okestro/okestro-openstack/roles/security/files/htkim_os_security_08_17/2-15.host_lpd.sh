file=/etc/hosts.lpd
passwd_permission_other=$(ls -la $file 2> /dev/null | awk '{print $1}' | cut -c8-10)
passwd_permission=$(ls -la $file 2> /dev/null | awk '{print $3}')
owner=0
group=0
other=0



if [ -e $file ];
then
	if [[ "$passwd_permission_other" == *"w"* ]];
	then
		echo "use write permisson"
	        echo -e "\033[0;31m$file Use Write Permission \033[0m"
	        echo -e "\033[0;31m$file Remove Write Permission \033[0m"
	        echo -e "$file Use Write Permission" >> change_list.txt
	        echo -e "$file Remove Write Permission" >> change_list.txt
		chmod 600 $file
	else
        	echo -e "\033[0;32m $file Permission GOOD!! \033[0m"
	fi

	if [[ "$passwd_permission" == "root" ]];
	then
                echo -e "\033[0;32m $file Permission GOOD!! \033[0m"
	else
                echo -e "\033[0;31m$file Not Use Root Permission \033[0m"
                echo -e "\033[0;31m$file Change $passwd_permission to Root \033[0m"
		chown root $file
	fi
else
        echo -e "\033[0;32mNot Exsit $file  GOOD!! \033[0m"
fi
