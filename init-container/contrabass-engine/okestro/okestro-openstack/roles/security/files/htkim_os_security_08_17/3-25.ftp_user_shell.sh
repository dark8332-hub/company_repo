ftp_check=$(ps -ef | grep vsftpd | grep -v grep)
file=/etc/passwd
shell=$(cat $file | grep -E '^ftp' | awk -F: '{print $NF}')

if [[ "$ftp_check" == "" ]];
then
        echo -e "\033[0;32mVSFTPD Process Not use!! \033[0m"
else
	if [[ "$shell" == "" ]];
	then
	      echo -e "\033[0;32mFTP User Not Exsit!! \033[0m"
	else
		for i in $shell
		do
			if [[ "$i" == "/usr/sbin/nologin" ]] || [[ "$i" == "/bin/false" ]];
			then
			        echo -e "\033[0;32mFTP User use shell GOOD!! \033[0m"
			else
				s1=$(echo $i | awk -F/ '{print $2}')
				s2=$(echo $i | awk -F/ '{print $3}')
		        	echo -e "\033[0;31mFTP User not use shell BAD!! \033[0m"
				sed -i "/^ftp/ s/\/$s1\/$s2/\/bin\/false/g" $file
		        	echo -e "FTP User not use $i BAD!!" >> change_list.txt
			fi
		done
	fi
fi

