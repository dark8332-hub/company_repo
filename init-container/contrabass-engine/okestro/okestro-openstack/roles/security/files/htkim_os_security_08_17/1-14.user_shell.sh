nologin_user=$(cat /etc/passwd | awk -F: '{print $1}' | egrep "^(daemon|bin|sys|adm|listen|nobody|nobody4|noaccess|diag|operator|games|gopher)")


for i in $nologin_user
do
        check=$(sed -n "/^$i/p" /etc/passwd)
        if [[ "$check" == *"nologin" ]] || [[ "$check" == *"false"* ]];
        then
                echo -e "\033[0;32m$i NoLogin Status!! \033[0m"
        else
                echo -e "\033[0;31m$i Use Login Status!! \033[0m"
                ch_user_shell=$(sed -n "/$i/p" /etc/passwd | awk -F: '{print $7}')
                s1=$(echo $ch_user_shell | awk -F/ '{print $2}')
                s2=$(echo $ch_user_shell | awk -F/ '{print $3}')
                sed -i  "/$i/ s/\/$s1\/$s2/\/usr\/sbin\/nologin/g" /etc/passwd
		echo "$i change not login" >> ./change_list.txt
        fi
done
