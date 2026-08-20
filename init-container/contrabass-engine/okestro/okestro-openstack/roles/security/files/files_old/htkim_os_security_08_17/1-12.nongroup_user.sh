gshadow=$(cat /etc/gshadow | egrep :$)

echo -e "\033[0;31mPLEASE COMMUNICATE WITH CUSTOMER \033[0m"
for i in $gshadow
do
        none_gshadow=$(echo $i | awk -F: '{print  $1}')
	echo $none_gshadow >> un_change_list.txt
done
