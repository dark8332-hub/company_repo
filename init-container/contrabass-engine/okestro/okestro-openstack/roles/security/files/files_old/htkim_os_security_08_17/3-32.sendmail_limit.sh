sendmail_check=$(ps -ef | grep sendmail | grep -v grep)
file=/etc/mail/sendmail.cf
limit_check=$(cat $file | grep PrivacyOptions | grep -v '^#')


if [[ "$sendmail_check" == "" ]];
then	
        echo -e "\033[0;32mSendMail Not Working!! \033[0m"
else
	if [[ "$limit_check" == *"noexpn"* ]];
	then
        	echo -e "\033[0;32mnoexpn options Exsit!! \033[0m"
	else
        	echo -e "\033[0;31mnoexpn options not Exsit!! \033[0m"
		sed -i "/$limit_check/ s/$/,noexpn/g" $file
        	echo -e "noexpn options add in $file" >> change_list.txt
		echo "sendmail service restart"
		systemctl restart sendmail
	fi
	if [[ "$limit_check" == *"novrfy"* ]];
	then
        	echo -e "\033[0;32mnovrfy options Exsit!! \033[0m"
	else
        	echo -e "\033[0;31mnovrfy options not Exsit!! \033[0m"
		sed -i "/$limit_check/ s/$/,novrfy/g" $file
        	echo -e "novrfy options add in $file" >> change_list.txt
		echo "sendmail service restart"
		systemctl restart sendmail
	fi

fi

