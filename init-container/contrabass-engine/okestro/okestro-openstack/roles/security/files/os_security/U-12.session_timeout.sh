# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
check_session=$(grep TMOUT /etc/profile)

if [[ "$check_session" == "" ]]; then
    echo -e "\033[0;31mTMOUT 미설정 - 600으로 추가\033[0m"
    echo "TMOUT=600" >> /etc/profile
    echo "export TMOUT" >> /etc/profile
    echo "[U-12] TMOUT 미설정 → 600 추가 (/etc/profile)" >> "$CHANGE"
    echo "[U-12] TMOUT 600 설정 완료 - Good" >> "$GOOD"
else
    session_count=$(grep TMOUT /etc/profile | awk -F= '{print $2}' | head -1)
    if [[ "$session_count" -gt "600" ]]; then
        sed -i "s/TMOUT=$session_count/TMOUT=600/g" /etc/profile
        echo -e "\033[0;31msession timeout $session_count 초과 - 600으로 변경\033[0m"
        echo "[U-12] TMOUT $session_count → 600 변경 (/etc/profile)" >> "$CHANGE"
        echo "[U-12] TMOUT 600으로 변경 완료 - Good" >> "$GOOD"
    else
        echo "[U-12] 세션 타임아웃 ${session_count}초 (600 이하) 양호 - Good" >> "$GOOD"
        echo -e "\033[0;32mSession timeout Good!!\033[0m"
    fi
fi
