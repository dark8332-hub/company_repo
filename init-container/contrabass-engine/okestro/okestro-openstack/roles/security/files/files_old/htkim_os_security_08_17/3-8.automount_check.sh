autofs_check=$(ps -ef | grep automount | grep -v 'grep')


if [[ "$autofs_check" == "" ]];
then
        echo -e "\033[0;32mAutoMount not use GOOD!! \033[0m"
else
	autofs_pid=$( echo $autofs_check | awk '{print $2}')
        echo -e "\033[0;31mAutoMount BAD use !! \033[0m"
        echo "AutoMount BAD use !!" >> change_list.txt
	echo "kill $autofs_pid is automount pid !!" >> change_list.txt
	kill -9 $autofs_pid
fi



