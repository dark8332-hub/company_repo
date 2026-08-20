nis_pid=$(ps -ef | egrep "ypbind|yppasswd|ypwhich" | grep -v grep | awk '{print $2}')


if [[ "$nis_pid" == ""  ]];
then
       echo -e "\033[0;32mNIS Service Not used \033[0m"		
else
	for i in $nis_pid
	do
		echo -e "\033[0;31mNis Service Used \033[0m"
                echo -e "\033[0;31mKill NIS Process $i \033[0m"
                echo  "NIS Service Used" >> change_list.txt
                kill -9 $i
	done
fi
