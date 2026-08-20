file=2-9.sticky_check_list.txt

while read line
do
	if [[ -e $line ]];
	then
		file_location=$(ls -alL $line | awk '{print $NF}')
		check=$(ls -laL $file_location | awk '{print $1}' | grep -i 's')
		if [[ "$check" == "" ]];
		then
			echo -e "\033[0;32m$file_location is Not use Sticky bit GOOD!! \033[0m"
		else
			echo -e "\033[0;31m$file_location is use Sticky bit BAD!! \033[0m"
			echo -e "$file_location is use Sticky bit" >> change_list.txt
			echo -e "$file_location remove Sticky bit" >> change_list.txt
			chmod -s $file_location
			
		fi
	else
		echo -e "\033[0;32m$line Not Exsit \033[0m"
	fi
done < 2-9.sticky_check_list.txt
