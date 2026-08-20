restrictqrun_check=$(grep -v '^ *#' /etc/mail/sendmail.cf | grep -i 'privacyoptions' | grep 'restrictqrun')
sendmail_check=$(ps -ef | grep sendmail | grep -v grep)

if [[ "$sendmail_check" == "" ]];
then
       	echo -e "\033[0;32mNot use SendMail \033[0m"
else
	if [[ "$restrictqrun_check" == "" ]];
	then
	        echo -e "\033[0;31mGeneral User can use BAD \033[0m"
	        echo "General User can use BAD" >> change_list.txt
		sed -ie '/PrivacyOptions/ s/$/,restrictqrun/g' /etc/mail/sendmail.cf
		systemctl restart sendmail
	else
	        echo -e "\033[0;32mGeneral User can't use GOOD \033[0m"
	fi
fi

