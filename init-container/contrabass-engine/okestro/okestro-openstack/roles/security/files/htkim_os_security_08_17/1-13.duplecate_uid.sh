duplicate_uid=$(cat /etc/passwd | awk -F: '{print $1" "$3}' | sort -k2 | uniq -f1 -D | awk '{print $1":"$2}' )


echo  "PLEASE COMMUNICATE WITH CUSTOMER" >> ./change_list.txt
echo -e "\033[0;31mPLEASE COMMUNICATE WITH CUSTOMER \033[0m"
for i in $duplicate_uid
do
        echo $i >> ./un_change_list.txt
done

