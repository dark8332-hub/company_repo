#user_list=$(cat /etc/passwd | awk -F: '$3 >= 1000 && $3 <60000 {print $1,$6}')

cat /etc/passwd | awk -F: '$3 >= 1000 && $3 <60000 {print $1,$6}' | while read line
do
	u_user=$(echo $line | awk '{print $1}') 
	u_hfile=$(echo $line | awk '{print $2}')
	u_owner=$(ls -ld $u_hfile | awk '{print$3}')
	


	ls -la $u_hfile | grep -E '.profile|.kshrc|.cshrc|.bashrc|.bash_logout|.bash_profile|.login|.exrc|.netrc|.bash_history' | while read line2
	do
	#u_dir=$(ls -ld $u_hfile | awk  -F/ '{print $NF}')

	u_file2=$(echo $line2 | awk '{print $NF}')
	u_other2=$(echo $line2 | awk '{print $1}' | cut -c8-10) 
	u_owner2=$(echo $line2 | awk '{print $3}')

	if [[ "$u_user" == "$u_owner2" ]];
	then
        	echo -e "\033[0;32mOnwer GOOD!! \033[0m"
	else
		echo -e "\033[0;31mOnwer BAD!!"
		echo -e  "User: $u_user  file $u_file2 BAD \nHome Dir Onwer: $u_owner \033[0m "
		echo -e "User: $u_user Home Directory BAD \nBAD FILE: /home/$u_user/$u_file2" >> change_list.txt
		echo -e "\033[0;31mOnwer Change \033[0m"
		chown $u_user /home/$u_user/$u_file2
	fi

	#perm_dir=$(ls -ld $u_hfile | awk '{print $1}' | cut -c8-10)
	if [[ "$u_other2" == *"w"* ]];
	then
		echo -e "\033[0;31mUse Write Permission!!\033[0m"
		echo -e "\033[0;31mRemove Write Permission!! /home/$u_user/$u_file2\033[0m"
		chmod o-w /home/$u_user/$u_file2
	else
        	echo -e "\033[0;32m$u_hfile Not use Write Permission GOOD!! \033[0m"
	fi
	done
done
