nfs_check=$(ps -ef | grep nfsd | grep -v grep)
#showmount_check=$(showmount -e | grep -v '[a-zA-Z]' > nfs_list.txt)
#nfs_list_file=nfs_list.txt
#showmount -e | grep -v '^[a-zA-Z]' > $nfs_list_file

mount_check=$(showmount -e | grep -v '^[a-zA-Z]' | grep '\*')


if [[ "$nfs_check" == "" ]];
then
        echo -e "\033[0;32mNot Use NFS \033[0m"
else
	if [[ "$mount_check" == "" ]];
	then
        	echo -e "\033[0;32mEveryOne Not exsit GOOD!! \033[0m"
	else
        	echo -e "\033[0;31mEveryOne exsit BAD!! \033[0m"
        	echo -e "EveryOne exsit BAD!! " >> un_change_list.txt
        	echo -e "EveryOne exsit Please Change EveryOne MountPoint " >> un_change_list.txt
	fi
fi
