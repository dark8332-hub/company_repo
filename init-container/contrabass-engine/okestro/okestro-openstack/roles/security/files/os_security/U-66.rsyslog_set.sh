# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

while IFS= read -r line
do
    check=$(grep -Fx "$line" /etc/rsyslog.conf)
    if [[ "$check" == "$line" ]]; then
        echo "[U-66] rsyslog 설정 존재 양호: $line - Good" >> "$GOOD"
        echo -e "\033[0;32m$line EXIST Good!!\033[0m"
    else
        echo -e "\033[0;31m$line 미설정 - 추가 조치\033[0m"
        echo "$line" >> /etc/rsyslog.conf
        echo "[U-66] rsyslog.conf 설정 추가: $line" >> "$CHANGE"
        echo "[U-66] rsyslog 설정 추가 완료: $line - Good" >> "$GOOD"
    fi
done < U-66.rsyslog_list.txt
