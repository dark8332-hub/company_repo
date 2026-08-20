min_day_size=$(cat /etc/login.defs | grep PASS_MIN_DAYS | grep -v '#'| awk '{print $2}')

## min_days size check

if [[ "$min_day_size" != 7 ]];
then
        sed -i "/PASS_MIN_DAYS/ s/$min_day_size$/7/" /etc/login.defs
        echo  "PASS_MIN_DAYS CHANGE  login.depfs" >> change_list.txt
        echo -e "\033[0;31mPASS_MIN_DAYS CHANGE  /etc/login.defs \033[0m"
else
        echo -e "\033[0;32mPASS_MIN_DAYS GOOD!! \033[0m"
fi
