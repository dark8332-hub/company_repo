file=/etc/ftpusers
check=$(cat $file | grep root | grep -E '^#')

if [[ "$check" == "" ]];
then
        echo -e "\033[0;31m ftpuser root use BAD!! \033[0m"
        echo -e "ftpuser root annotations" >> change_list.txt
	sed -i "s/root/#root/g" $file
else
        echo -e "\033[0;32m ftpuser root Not use GOOD!! \033[0m"
fi



