sshd_check=$(ps -ef | grep sshd | grep -v grep)

if [[ "$sshd_check" == "" ]];
then
        echo -e "\033[0;32mSSHD Process Not use!! \033[0m"
else
        echo -e "\033[0;31mSSHD Process  use!! \033[0m"
        echo -e "SSHD Process  use!!" >> un_change_list.txt
fi

