rgroup=$(egrep '^root' /etc/group | awk -F':' '{print $4}')

if [[ "$rgroup" == "" ]];
then
        echo -e "\033[0;32mROOT GROUP USER NONE!! \033[0m"
else
        echo -e "\033[0;31mROOT GROUP USER EXIST!! \033[0m"
        echo -e "\033[0;31mPLEASE COMMUNICATE WITH CUSTOMER \033[0m"
        for i in $rgroup
        do
        echo $i >> ./un_change_list.txt
        done
fi
