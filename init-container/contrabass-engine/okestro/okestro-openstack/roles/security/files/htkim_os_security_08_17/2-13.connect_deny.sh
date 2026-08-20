cat /etc/hosts.deny | grep -v '^#' | grep 'ALL:ALL' > /dev/null 2>&1

if [ $? -eq 0 ];then
        echo -e "\033[0;32m/etc/hosts File Status GOOD!! \033[0m"
else
        echo -e "\033[0;31m/etc/hosts.deny File add ALL:ALL  \033[0m"
	echo "#ALL:ALL" >> /etc/hosts.deny
        echo -e "\033[0;31mPlease ADD allowed ips etc/hosts.allow \033[0m"
        echo  "Please ADD allowed ips etc/hosts.allow" >> un_change_list.txt
fi

