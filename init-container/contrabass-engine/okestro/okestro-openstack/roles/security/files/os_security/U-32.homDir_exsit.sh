# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

cat /etc/passwd | awk -F: '$3 >= 1000 && $3 <60000 {print $1,$6}' | while read line
do
    u_user=$(echo $line | awk '{print $1}')
    u_hfile=$(echo $line | awk '{print $2}')

    if [[ -e $u_hfile ]]; then
        echo "[U-32] $u_user 홈 디렉터리 존재 양호 - Good" >> "$GOOD"
        echo -e "\033[0;32m$u_user Home Directory Exist Good!!\033[0m"
    else
        echo -e "\033[0;31m$u_user 홈 디렉터리 없음 - 생성 조치\033[0m"
        mkdir -p $u_hfile
        echo "[U-32] $u_user 홈 디렉터리 $u_hfile 생성" >> "$CHANGE"
        echo "[U-32] $u_user 홈 디렉터리 생성 완료 - Good" >> "$GOOD"
    fi
done
