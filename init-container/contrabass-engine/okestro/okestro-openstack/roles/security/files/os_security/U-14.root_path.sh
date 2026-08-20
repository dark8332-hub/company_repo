# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
file=/etc/environment
env_check=$(cat $file | awk -F= '{print$2}' | sed 's/^"//' | sed 's/"$//')
env_check2=$(echo $env_check | grep -E "^\.|\/\.|:\.|\.[a-z]")

if [[ "$env_check2" == "" ]]; then
    echo "[U-14] PATH 환경변수 양호 - Good" >> "$GOOD"
    echo -e "\033[0;32mEnvironment Value Good!!\033[0m"
else
    echo -e "\033[0;31mPATH에 . 포함 - 제거 조치\033[0m"
    sed -i "s/\.//g" $file
    source $file
    echo "[U-14] PATH 환경변수에서 . 제거 ($file)" >> "$CHANGE"
    echo "[U-14] PATH 환경변수 . 제거 완료 - Good" >> "$GOOD"
fi
