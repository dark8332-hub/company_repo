nfs_check=$(ps -ef | grep nfsd | grep -v grep)


if [[ "$nfs_check" == "" ]];
then
        echo -e "\033[0;32mNot use NFS Service GOOD!! \033[0m"
else
        echo -e "\033[0;31mUsing NFS Service BAD!! \033[0m"
        echo "Using NFS Service " >> un_change_list.txt
fi
