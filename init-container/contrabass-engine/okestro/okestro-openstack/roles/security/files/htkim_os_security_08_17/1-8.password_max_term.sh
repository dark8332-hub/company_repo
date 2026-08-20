max_day_size=$(cat /etc/login.defs | grep PASS_MAX_DAYS | grep -v '#'| awk '{print $2}')

## max_days size check

if [[ "$max_day_size" -gt 90 ]];
then
        sed -i "/PASS_MAX_DAYS/ s/$max_day_size$/90/" /etc/login.defs
        echo  "PASS_MAX_DAYS CHANGE  login.depfs" >> change_list.txt
        echo -e "\033[0;31mPASS_MAX_DAYS CHANGE  /etc/login.defs \033[0m"
else
        echo -e "\033[0;32mPASS_MAX_DAYS GOOD!! \033[0m"
fi
