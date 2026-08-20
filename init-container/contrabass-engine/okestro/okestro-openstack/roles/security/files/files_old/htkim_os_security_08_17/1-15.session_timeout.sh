check_session=$(cat /etc/profile | grep TMOUT)



if [[ "$check_session" == "" ]];
then
        echo TMOUT=600 >> /etc/profile
        source /etc/profile
        echo -e "\033[0;31m TIMOUT NOT SETTINGS !! \033[0m"
        echo "time out setting change in /etc/profile" >> change_list.txt
fi

session_count=$(grep TMOUT /etc/profile | awk -F= '{print $2}')

if [[ "$session_count" -lt "600" ]];
then
        sed -i "s/TMOUT=$session_count/TMOUT=600/g" /etc/profile
        echo -e "\033[0;31m session timeout less than 600 !! \033[0m"
        echo "Change the session timeout value from $session_count to 600" >> change_list.txt
fi
