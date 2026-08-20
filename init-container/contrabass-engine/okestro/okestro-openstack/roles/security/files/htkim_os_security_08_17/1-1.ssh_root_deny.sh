check_sshd=$(cat /etc/ssh/sshd_config | grep -i permitrootlogin | grep -v '#')
check_file=/etc/ssh/sshd_config



if [[ "$check_sshd" == *"yes"* ]]; 
then
	sed -i '/PermitRootLogin/ s/yes/yes/g' /etc/ssh/sshd_config
	echo -e "\033[0;31msshd_config PermitRootLogin option change yes to no ### \033[0m"
	echo $check_file change PermitRootLogin option >> change_list.txt
	echo "#원격 루트 접속 제한" >> change_list.txt
	systemctl restart sshd
else
	echo -e "\033[0;32mPermitRootLogin GOOD!! \033[0m"
fi

