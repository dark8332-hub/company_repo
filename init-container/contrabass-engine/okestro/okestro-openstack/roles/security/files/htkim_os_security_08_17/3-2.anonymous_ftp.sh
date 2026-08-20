ftp_user=$(cat /etc/passwd |  grep ftp)

if [[ "$ftp_user" == *"ftp"* ]];
then
        echo -e "\033[0;32mFTp User exist Remove FTP User \033[0m"
        echo -e "FTp User exist Remove FTP User" >> change_list.txt
	deluser ftp
else
        echo -e "\033[0;32mFTP User Not exsit GOOD!! \033[0m"
fi


vsftp_check=$(dpkg -l | grep vsftpd)
anonymous_enable=$(cat /etc/vsftpd.conf | grep anonymous_enable | awk -F= '{print $2}')

if [[ "$vsftp_check" == "" ]];
then
        echo -e "\033[0;32mFTP User Not exsit GOOD!! \033[0m"
else
	if [[ "$anonymous_enable" == "NO" ]];
	then
        	echo -e "\033[0;32mFTP Anonymous Permit GOOD!! \033[0m"
	else
        	echo -e "\033[0;31mFTP Anonymous Permit BAD!! \033[0m"
        	echo "FTP Anonymous Permit BAD!!"  >> change_list.txt
		echo "change anonymous_enable=NO in /etc/vsftpd.conf"  >> change_list.txt
		sed -i "s/anonymous_enable=$anonymous_enable/anonymous_enable=NO/g" /etc/vsftpd.conf
	fi

fi

