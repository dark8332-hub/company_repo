group_list=$(cat /etc/group | grep wheel)

if [[ "$group_list" == *"wheel"* ]];
then
        echo -e "\033[0;32mWHEEL GROUP ALREADY EXSIT \033[0m"
else
        groupadd wheel
        echo -e "\033[0;31mGROUPADD WHEEL \033[0m"
        echo GROUPADD WHEEL PLEASE COMMUNICATE WITH CUSTOMER FOR USE SU GROUP >> ./un_change_list.txt
fi


pam_check=$(cat /etc/pam.d/su | grep -v '#' | grep pam_wheel.so)

if [[ "$pam_check" == *"pam_wheel.so"* ]];
then
	echo -e "\033[0;32mPAM_WHEEL.SO MODULE USING!! \033[0m"
else
	echo -e "\033[0;31mNOT USED PAM MODULE \033[0m"
        echo  "auth    required        pam_wheel.so debug=wheel" >> /etc/pam.d/su
	echo "auth requried pam_wheel.so debug=wheel in /etc/pam.d/su" >> ./change_list.txt
fi
