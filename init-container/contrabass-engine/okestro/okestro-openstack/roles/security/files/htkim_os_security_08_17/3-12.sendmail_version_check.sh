sendmail_check=$(ps -ef | grep sendmail | grep -v grep)
sendmail_VersionCheck=`expr $(dpkg -l | grep sendmail | awk '{print $3}' | awk -F- '{print $1}' | head -n1)`
sendVersion_standard_minus1=`expr 8.13.7`
#sendVersion_standard=`expr 8.13.8`


if [[ "$sendmail_check" == "" ]];
then
        echo -e "\033[0;32mSendMail Service Not Use !! \033[0m"
else
	if [[ $sendmail_VersionCheck > $sendVersion_standard_minus1 ]];
	then
	        echo -e "\033[0;32mSendMail Version $sendmail_VersionCheck GOOD!! \033[0m"
	else
	        echo -e "\033[0;31mSendMail Version $sendmail_VersionCheck BAD!! \033[0m"
	        echo "SendMail Version $sendmail_VersionCheck Please Upgrade Sendmail Version" >> un_change_list.txt
	fi
fi

#a=`expr 7.5.1`
#b=`expr 7.5.2`

#if [[ $a > $b  ]];
#then
#	echo good
#else
#	echo no
#fi
