passwd_protect=$(cat /etc/passwd | awk -F ':' '{print $1":"$2}' | grep -vh ':x$')

for i in $passwd_protect
do
	echo -e "\033[0;31m$i The second field in the /etc/passwd file is not x!!! PLEASE CHANGE SECOND FILED!!! \033[0m"
	echo "## PASSWD_PROTECT ##" >> change_list.txt
        echo  $i The second filed in the /etc/passwd CHANGE X >> change_list.txt
	echo $i | awk -F ':' '{print $1}'
	waring_user=$(echo $i | awk -F ':' '{print $1}')
        sed -i "s/$i/$waring_user:x/g" /etc/passwd > /dev/null 2>&1
done


ls /etc/shadow > /dev/null 2>&1

if [ $? -eq 0 ];
then
	        echo -e "\033[0;32mSHADOW FILE EXIST! \033[0m"
	else
		 echo -e "\033[0;31m NOT EXIST SHADOW FILE!!! \033[0m"
       		 echo "## SHADOW FILE ##" >> change_list.txt
        	 echo  CREATE /ETC/SHADOW FILE >> change_list.txt
		 cp /etc/shadow- /etc/shadow

fi	


