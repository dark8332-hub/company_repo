min_pass=$(cat /etc/login.defs | grep PASS_MIN_LEN)
min_pass_quo=$(cat /etc/login.defs | grep PASS_MIN_LEN | awk '{print $2}')
#complex_config_file=$(cat /etc/pam.d/common-password | grep password | grep -v '#' | grep 'pam_unix.so')
complex_config_file=$(cat /etc/pam.d/common-password | grep minclass)
package_check=$(dpkg -l | grep libpam-pwquality)

## min password

if [[ "$min_pass" == *"#"* ]];
then
	sed -i '/PASS_MIN_LEN/ s/^.//' /etc/login.defs
	echo  "PASS_MIN_LEN UNCOMMENTS IN /etc/pam.d/common-password" >> change_list.txt
	echo "#common-password 주석 해제" >> change_list.txt
	echo -e "\033[0;31mPASS_MIN_LEN UNCOMMENTS IN /etc/pam.d/common-password \033[0m"
else
	echo -e "\033[0;32mMIN_PASSWORD_LEN COMMENT STATS GOOD!! \033[0m"
fi

if [[ "$min_pass_quo" -ge 8 ]];
then
	echo -e "\033[0;32mMIN_PASSWORD_LEN GOOD!! \033[0m"
else
	sed -ie "/PASS_MIN_LEN/ s/PASS_MIN_LEN $min_pass_quo/PASS_MIN_LEN 8/" /etc/login.defs
	echo  "PASS_MIN_LEN CHANGE  /etc/pam.d/ /etc/login.defs" >> change_list.txt
	echo "#common-password PASS_MIN_LEN 8 설정 " >> change_list.txt
	echo -e "\033[0;31mPASS_MIN_LEN CHANGE  /etc/pam.d/common-password \033[0m"
fi

## package check 


if [ "$package_check" == ""  ];
then
	echo  "install libpam-pwquality" >> change_list.txt
	echo  "#libpam-pwquality 패키지 설치" >> change_list.txt
	apt install libpam-pwquality -y
else
	echo -e "\033[0;32mlibam-pwquality already installed! \033[0m"
fi
	


## minclass check

if [[ "$complex_config_file" == *"minclass"* ]];
then
	echo -e "\033[0;32mMINCLASS IS EXIST! \033[0m"
else
        sed -ie "/pam_pwquality.so/ s/$/ minclass=3/g" /etc/pam.d/common-password
	echo -e "add minclass /etc/pam.d/common-password" >> change_list.txt
	echo -e "MINCLASS /etc/apm.d/common-password에 삽입 후 3으로 설정" >> change_list.txt
	echo -e "\033[31mADD MINCLASS /etc/pam.d/common-password"
fi

## minclass size check

for i in $complex_config_file
do
        if [[ "$i" == *"minclass"* ]];
        then
                min_size=$(echo -e ${i} | awk -F '=' '{print $2}')
                if [[ "$min_size" -lt 3 || "$min_size" -gt 4 ]];
                then
                        echo $min_size
                        sed -i "s/minclass=$min_size/minclass=3/g" /etc/pam.d/common-password
			echo  "change minclass /etc/pam.d/common-password" >> change_list.txt
			echo -e "MINCLASS  3으로 설정" >> change_list.txt
			echo -e "\033[31mCHANGE MINCLASS SIZE /etc/pam.d/common-password"
                fi
        fi
done

