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
    u_owner=$(ls -ld $u_hfile 2>/dev/null | awk '{print$3}')

    if [[ "$u_user" == "$u_owner" ]]; then
        echo "[U-31] $u_user 홈 디렉터리 소유자 양호 - Good" >> "$GOOD"
        echo -e "\033[0;32mOwner Good!!\033[0m"
    else
        echo -e "\033[0;31m$u_user 홈 디렉터리 소유자 이상 - 변경 조치\033[0m"
        chown $u_user $u_hfile
        echo "[U-31] $u_hfile 소유자 $u_user 로 변경" >> "$CHANGE"
        echo "[U-31] $u_user 홈 디렉터리 소유자 변경 완료 - Good" >> "$GOOD"
    fi

    perm_dir=$(ls -ld $u_hfile 2>/dev/null | awk '{print $1}' | cut -c8-10)
    if [[ "$perm_dir" == *"w"* ]]; then
        echo -e "\033[0;31m$u_hfile others 쓰기권한 발견 - 제거 조치\033[0m"
        chmod o-w $u_hfile
        echo "[U-31] $u_hfile others 쓰기권한 제거" >> "$CHANGE"
        echo "[U-31] $u_hfile others 쓰기권한 제거 완료 - Good" >> "$GOOD"
    else
        echo "[U-31] $u_hfile others 쓰기권한 없음 양호 - Good" >> "$GOOD"
        echo -e "\033[0;32m$u_hfile Not use Write Permission Good!!\033[0m"
    fi
done
