#user_list=$(cat /etc/passwd | awk -F: '$3 >= 1000 && $3 <60000 {print $1,$6}')

cat /etc/passwd | awk -F: '$3 >= 1000 && $3 <60000 {print $1,$6}' | while read line
do
	u_user=$(echo $line | awk '{print $1}') 
	u_hfile=$(echo $line | awk '{print $2}')
	u_owner=$(ls -ld $u_hfile | awk '{print$3}')
	#u_dir=$(ls -ld $u_hfile | awk  -F/ '{print $NF}')


	if [[ "$u_user" == "$u_owner" ]];
	then
        	echo -e "\033[0;32mOnwer GOOD!! \033[0m"
	else
		echo -e "\033[0;31mOnwer BAD!!"
		echo -e  "User: $u_user Home Directory BAD \nHome Dir Onwer: $u_owner \033[0m "
		echo -e "User: $u_user Home Directory BAD \nHome Dir Onwer: $u_owner" >> change_list.txt
		echo -e "\033[0;31mOnwer Change \033[0m"
		chown $u_user $u_hfile
	fi

	perm_dir=$(ls -ld $u_hfile | awk '{print $1}' | cut -c8-10)
	if [[ "$perm_dir" == *"w"* ]];
	then
		echo -e "\033[0;31mUse Write Permission!!\033[0m"
		echo -e "\033[0;31mRemove Write Permission!! $u_hfile\033[0m"
		chmod o-w $u_hfile
	else
        	echo -e "\033[0;32m$u_hfile Not use Write Permission GOOD!! \033[0m"
	fi
done
