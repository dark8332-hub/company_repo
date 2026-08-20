# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
nologin_user=$(awk -F: '{print $1}' /etc/passwd | egrep '^(daemon|bin|sys|adm|listen|nobody|nobody4|noaccess|diag|operator|games|gopher)$')

for i in $nologin_user
do
    ch_user_shell=$(awk -F: -v user="$i" '$1 == user {print $7}' /etc/passwd)

    if [[ "$ch_user_shell" == *"nologin" ]] || [[ "$ch_user_shell" == *"false"* ]]; then
        echo "[U-11] $i: nologin/false 설정 양호 - Good" >> "$GOOD"
        echo -e "\033[0;32m$i NoLogin Status Good!!\033[0m"
    else
        echo -e "\033[0;31m$i: login 가능 shell 발견 - nologin으로 변경\033[0m"
        usermod -s /usr/sbin/nologin "$i"
        echo "[U-11] $i shell → /usr/sbin/nologin 변경" >> "$CHANGE"
        echo "[U-11] $i: shell nologin으로 변경 완료 - Good" >> "$GOOD"
    fi
done
