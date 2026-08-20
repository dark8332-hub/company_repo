rlist=$(cat 5-1.rsyslog_list.txt | awk '{print $1}')


while read line
do
        check=$(cat /etc/rsyslog.conf | grep -F "$line")
        if [[ "$check" == *"$line"* ]];
        then
                echo -e "\033[0;32m$line is EXSIT!! \033[0m"
        else
                echo -e "\033[0;31m"$line" is not found \033[0m"
                echo "$line" >> /etc/rsyslog.conf
        fi
done < rsyslog_list.txt
