passwd_check=$(cat /etc/passwd | awk -F ':' '{print $1":"$2":"$3}' | grep -v root | grep -h ':0$' )

for i in $passwd_check
do
	echo -e "\033[0;31m$i USED ROOT UID!!! PLEASE CHANGE UID\033[0m"
	echo  $i used ROOT UID!! >> un_change_list.txt
done
