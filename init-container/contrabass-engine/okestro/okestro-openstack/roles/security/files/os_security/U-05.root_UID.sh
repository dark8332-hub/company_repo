# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
passwd_check=$(cat /etc/passwd | awk -F ':' '{print $1":"$2":"$3}' | grep -v root | grep -h ':0$' )

for i in $passwd_check
do
	echo -e "\033[0;31m$i USED ROOT UID!!! PLEASE CHANGE UID\033[0m"
	echo "[U-05] $i: UID=0 발견 - 변경 필요" >> "$BAD"
	echo  $i used ROOT UID!! >> "$BAD"
done

if [[ -z "$passwd_check" ]]; then
	echo "[U-05] root 외 UID=0 없음 양호 - Good" >> "$GOOD"
	echo -e "\033[0;32mRoot UID Check Good!! \033[0m"
fi
