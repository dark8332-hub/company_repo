file1=/etc/issue.net
file2=/etc/motd

if [[ -e $file1 ]];
then
        echo -e "\033[0;32m$file1 Exsit GOOD!! \033[0m"
	file1_check=$(cat $file1)
	if [[ "$file1_check" == *"Ubuntu 20.04.2 LTS"* ]];
	then
        	echo -e "\033[0;31m$file1 Content is Contain OS Name Please Change $file1 Content\033[0m"
        	echo -e "$file1 Content Contain OS Name Please Change $file1 Content" >> un_change_list.txt
	else
       		echo -e "\033[0;32m$file1 Content Not Contain OS Name GOOD!! \033[0m"
	fi

else
        echo -e "\033[0;31m$file1 Not Exsit BAD!! \033[0m"
	touch $file1
        echo -e "$file1 Create!!" >> change_list.txt
fi

if [[ -e $file2 ]];
then
        echo -e "\033[0;32m$file2 Exsit GOOD!! \033[0m"
	file2_check=$(cat $file2)
	if [[ "$file2_check" == "" ]];
	then
        	echo -e "\033[0;31m$file2 Content NULL Please add Content \033[0m"
        	echo -e "$file2 Content NULL Please add Content" >> un_change_list.txt
	else 
        	echo -e "\033[0;32m$file2 Exsit Content GOOD!! \033[0m"
	fi

else
        echo -e "\033[0;31m$file2 Not Exsit BAD!! \033[0m"
	touch $file2
        echo -e "$file2 Create!!" >> change_list.txt
fi
