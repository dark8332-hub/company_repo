sshd_check=$(ps -ef | grep vsftpd | grep -v grep)

if [[ "$sshd_check" == "" ]];
then
        echo -e "\033[0;32mVSFTPD Process Not use!! \033[0m"
else
        echo -e "\033[0;31mVSFTPD Process  use!! \033[0m"
        echo -e "VSFTPD Process  use!!" >> un_change_list.txt
fi

