min_pass=$(cat /etc/login.defs | grep PASS_MIN_LEN)
min_pass_quo=$(cat /etc/login.defs | grep PASS_MIN_LEN | awk '{print $2}')

if [[ "$min_pass" == *"#"* ]];
then
        sed -i '/PASS_MIN_LEN/ s/^.//' /etc/login.defs
        echo  "PASS_MIN_LEN UNCOMMENTS IN /etc/pam.d/common-password" >> change_list.txt
        echo -e "\033[0;31mPASS_MIN_LEN UNCOMMENTS IN /etc/pam.d/common-password \033[0m"
else
        echo -e "\033[0;32mMIN_PASSWORD_LEN COMMENT STATS GOOD!! \033[0m"
fi

if [[ "$min_pass_quo" -ge 9 ]];
then
        echo -e "\033[0;32mMIN_PASSWORD_LEN GOOD!! \033[0m"
else
	if [[ "$min_pass_quo" == "" ]];
	then
        	sed -i "/PASS_MIN_LEN/ s/PASS_MIN_LEN/PASS_MIN_LEN 9/" /etc/login.defs
        	echo  "PASS_MIN_LEN CHANGE  /etc/login.defs" >> change_list.txt
        	echo -e "\033[0;31mPASS_MIN_LEN CHANGE  /etc/login.defs \033[0m"
	else
        	sed -i "/PASS_MIN_LEN/ s/PASS_MIN_LEN $min_pass_quo/PASS_MIN_LEN 9/" /etc/login.defs
        	echo  "PASS_MIN_LEN CHANGE  /etc/login.defs" >> change_list.txt
        	echo -e "\033[0;31mPASS_MIN_LEN CHANGE  /etc/login.defs \033[0m"
	fi
fi

