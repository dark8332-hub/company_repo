# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
duplicate_uid=$(cat /etc/passwd | awk -F: '{print $1" "$3}' | sort -k2 | uniq -f1 -D | awk '{print $1":"$2}' )

if [[ -n "$duplicate_uid" ]]; then
    echo "[U-10] 중복 UID 발견 - 고객 연락 필요 (PLEASE COMMUNICATE WITH CUSTOMER)" >> "$CHANGE"
    echo "[U-10] 중복 UID 발견 - 담당자 확인 필요" >> "$BAD"
    echo -e "\033[0;31mPLEASE COMMUNICATE WITH CUSTOMER \033[0m"
    for i in $duplicate_uid
    do
            echo $i >> "$BAD"
    done
else
    echo "[U-10] 중복 UID 없음 양호 - Good" >> "$GOOD"
    echo -e "\033[0;32mDuplicate UID check Good!! \033[0m"
fi
