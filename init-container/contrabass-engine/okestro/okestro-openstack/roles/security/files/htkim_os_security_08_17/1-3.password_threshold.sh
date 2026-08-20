threshold_config_file=$(cat /etc/pam.d/common-password | grep retry)
threshold_config_file2=$(cat /etc/pam.d/common-auth | grep deny)

## threshold check

if [[ "$threshold_config_file" == *"retry"* ]];
then
        echo -e "\033[0;32mRETRY IS EXIST! \033[0m"
else
        sed -ie "/pam_pwquality.so/ s/$/ retry=5/g" /etc/pam.d/common-password
       	echo -e "\033[0;31mADD RETRY /etc/pam.d/common-password  \033[0m"
       	echo -e "/etc/pam.d/common-password 에 임계값 설정" >> change_list.txt
        echo -e "add retry /etc/pam.d/common-password" >> change_list.txt
fi

## threshold size check

for i in $threshold_config_file
do
        if [[ "$i" == *"retry"* ]];
        then
                retry_size=$(echo -e ${i} | awk -F '=' '{print $2}')
                if [[ "$retry_size" -le 4 ]];
                then
                        sed -i "s/retry=$retry_size/retry=5/g" /etc/pam.d/common-password
       			echo -e "/etc/pam.d/common-password 에 5로 임계값 설정" >> change_list.txt
        		echo -e "\033[0;31mCHANGE RETRY  \033[0m"
                        echo  "change retry /etc/pam.d/common-password" >> change_list.txt
                fi
        fi
done

if [[ "$threshold_config_file" == *"deny"* ]];
then
        echo -e "\033[0;32mRETRY IS EXIST! \033[0m"
else
        sed -ie "/pam_pwquality.so/ s/$/ deny=5/g" /etc/pam.d/common-password
       	echo -e "\033[0;31mADD deny /etc/pam.d/common-password  \033[0m"
        echo -e "add deny /etc/pam.d/common-password" >> change_list.txt
       	echo -e "/etc/pam.d/common-password 에 deny 설정" >> change_list.txt
fi

## threshold size check

for i in $threshold_config_file
do
        if [[ "$i" == *"deny"* ]];
        then
                deny_size=$(echo -e ${i} | awk -F '=' '{print $2}')
                if [[ "$deny_size" -le 4 ]];
                then
                        sed -i "/pam_pwquality.so/ s/deny=$deny_size/deny=5/g" /etc/pam.d/common-password
        		echo -e "\033[0;31mCHANGE deny  \033[0m"
                        echo  "change minclass /etc/pam.d/common-password" >> change_list.txt
       			echo -e "/etc/pam.d/common-password 에 deny 설정" >> change_list.txt
                fi
        fi
done






if [[ "$threshold_config_file2" == *"pam_tally2.so"* ]];
then
        echo -e "\033[0;32mPAM_TALLY2.SO IS EXIST! \033[0m"
else
        sed -i "-r -e s/success/i " /etc/pam.d/common-password
       	echo -e "\033[0;31mADD RETRY /etc/pam.d/common-password  \033[0m"
        echo -e "add retry /etc/pam.d/common-password" >> change_list.txt
       	echo -e "/etc/pam.d/common-password에 deny 설정" >> change_list.txt
fi

## threshold size check

for i in $threshold_config_file
do
        if [[ "$i" == *"retry"* ]];
        then
                retry_size=$(echo -e ${i} | awk -F '=' '{print $2}')
                if [[ "$retry_size" -le 4 ]];
                then
                        sed -i "s/retry=$retry_size/retry=5/g" /etc/pam.d/common-password
        		echo -e "\033[0;31mCHANGE RETRY  \033[0m"
                        echo  "change retry /etc/pam.d/common-password" >> change_list.txt
                        echo  "/etc/pam.d/common-password retry 사이즈 5로 설정" >> change_list.txt
                fi
        fi
done




threshold_config_file2=$(cat /etc/pam.d/common-auth | grep pam_tally2.so)

if [[ "$threshold_config_file2" == *"pam_tally2.so"* ]];
then
        echo -e "\033[0;32mPAM_TALLY2.SO IS EXIST! \033[0m"
else
        sed -ie "16 i\auth      required        pam_tally2.so onerr=fail even_deny_root deny=5 unlock_time=600" /etc/pam.d/common-auth
        echo -e "\033[0;31mADD RETRY /etc/pam.d/common-auth  \033[0m"
        echo -e "add retry /etc/pam.d/common-auth" >> change_list.txt
        echo -e "/etc/pam.d/common-auth retry 설정" >> change_list.txt
fi


## threshold size check

for i in $threshold_config_file2
do
        #echo $i | grep deny
        if [[ "$i" == "deny"* ]];
        then
                deny_size=$(echo -e ${i} | awk -F '=' '{print $2}')
                if [[ $deny_size -le 4 ]];
                then
                        sed -i "/pam_tally2.so/ s/deny=$deny_size/deny=5/g" /etc/pam.d/common-auth
                        echo -e "\033[0;31mCHANGE DENY SIZE  \033[0m"
                        echo  "DENY SIZE /etc/pam.d/common-auth" >> change_list.txt
                        echo  "DENY SIZE 5로 설정 /etc/pam.d/common-auth" >> change_list.txt
                fi
        fi
done
