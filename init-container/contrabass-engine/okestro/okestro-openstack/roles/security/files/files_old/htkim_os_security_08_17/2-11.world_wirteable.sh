word_writeable=$(find / -perm -2 -ls 2> /dev/null | egrep -v '/proc|rwx|/tmp' | awk '{print $NF}')


echo -e "\033[0;31mWorld Writeable List \033[0m"	
echo -e "World Writeable List \n" >> change_list.txt
for i in $word_writeable
do
        echo $i 
        echo $i  >> un_change_list.txt
done
echo  "PLEASE COMMUNICATE WITH CUSTOMER" >> ./change_list.txt
