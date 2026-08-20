#user_list=$(cat /etc/passwd | awk -F: '$3 >= 1000 && $3 <60000 {print $1,$6}')

cat /etc/passwd | awk -F: '$3 >= 1000 && $3 <60000 {print $1,$6}' | while read line
do
	u_user=$(echo $line | awk '{print $1}') 
	u_hfile=$(echo $line | awk '{print $2}')
	#u_owner=$(ls -ld $u_hfile | awk '{print$3}')
	
	if [[ -e $u_hfile ]];
	then
	        echo -e "\033[0;32m$u_user Home Driectory Exsit!! \033[0m"
	else
		echo -e "\033[0;31m$u_user Home Directory not exist \033[0m"
		echo -e "$u_user Home Directory not exist" >> change_list.txt
		echo "$u_user Home Directory create" >> change_list.txt
		echo -e "\033[0;31m$u_user Home Directory create $u_hfile \033[0m"
		mkdir -p $u_hfile	
	fi
	

done

