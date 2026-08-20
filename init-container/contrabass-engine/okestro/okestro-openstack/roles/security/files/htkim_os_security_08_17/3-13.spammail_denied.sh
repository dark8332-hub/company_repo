denied_check=$(cat /etc/mail/sendmail.cf | grep "R$\*" | grep "Relaying denied" | grep -h '^#')
sendmail_check=$(ps -ef | grep sendmail | grep -v grep)

if [[ "$sendmail_check" == "" ]];
then
        echo -e "\033[0;32mSendmail not use!! \033[0m"
else
	if [[ "$denied_check" == "" ]];
	then
        	echo -e "\033[0;32mSpamMail denied good!! \033[0m"
	else
        	echo -e "\033[0;31mSpamMail Not denied BAD!! \033[0m"
		sed  -i "/Relaying denied/ s/^#//g" /etc/mail/sendmail.cf
        	echo -e "SpamMail Not denied Relaying denied line unannotation" >> change_list.txt
					
	fi
fi
