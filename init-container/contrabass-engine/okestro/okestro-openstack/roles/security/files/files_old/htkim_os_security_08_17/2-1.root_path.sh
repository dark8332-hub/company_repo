file=/etc/environment
env_check=$(cat $file | awk -F= '{print$2}' | sed 's/^"//' | sed 's/"$//')
env_check2=$(echo $env_check  | grep -E "^\.|\/\.|:\.|\.[a-z]")


if [[ "$env_check2" == "" ]];
then
        echo -e "\033[0;32mEnviroment Value GOOD!! \033[0m"
else
        echo -e "\033[0;31mEnviroment Value BAD!! \033[0m"
        echo -e "Enviroment Value Contain . " >> change_list.txt
        echo -e "Remove . in $file " >> change_list.txt
	sed -i "s/\.//g" $file
	source $file

fi
