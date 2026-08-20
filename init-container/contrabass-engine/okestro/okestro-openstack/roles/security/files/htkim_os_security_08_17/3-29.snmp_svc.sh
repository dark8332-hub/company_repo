snmp_svc=$(ps -ef | grep snmp | grep -v snmp | awk '{print $3}')


if [[ "$snmp_svc" == "" ]];
then
        echo -e "\033[0;32mSNMP Service Not use GOOD!! \033[0m"
else
        echo -e "\033[0;31mSNMP Service use BAD!! \033[0m"
        echo -e "SNMP Service use " >> change_list.txt
        echo -e "SNMP Service kill!!" >> change_list.txt
	kill -9 $snmp_svc
fi

