dns_check=$(ps -ef | grep "named -f -u bind" | grep -v grep)
transper_check=$(cat /etc/bind/* | grep allow-transfer | grep -Ev '^//|//allow-transfer|allow-transfer*//*')

if [[ "$dns_check" == "" ]];
then
        echo -e "\033[0;32mDNS Service Not Use !! \033[0m"
else
	cat /etc/bind/* | grep allow-transfer | grep -Ev '^//|//allow-transfer|allow-transfer*//*' | while read line
	do
		if [[ "$line" == "" ]];
		then
	       		 echo -e "\033[0;32mTransper Not Use GOOD!! \033[0m"
		else
	       		 echo -e "\033[0;31mTransper Use BAD!! \033[0m"
			 sed -i "s/$line/\/\/$line/g" /etc/bind/named.conf.options
			 echo "sed -i "s/$line/\/\/$line/g" /etc/bind/named.conf.options" >> change_list.txt
		fi
	done

fi

