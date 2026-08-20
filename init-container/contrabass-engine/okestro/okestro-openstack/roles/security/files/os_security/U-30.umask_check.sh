#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# PDF U-30: UMASK 022 이상 설정 여부 점검
# 양호: /etc/profile 에 umask 022 이하 설정

file=/etc/profile
cur_umask_str=$(umask)
# 10진수로 변환 (umask 출력은 0022 형식)
cur_umask_dec=$((8#${cur_umask_str}))
# 8진수 022 = 10진수 18
UMASK_THRESHOLD=18

echo "========== [U-30] UMASK 점검 =========="

if [[ "$cur_umask_dec" -le "$UMASK_THRESHOLD" ]]; then
    echo "[U-30] UMASK ${cur_umask_str} (022 이하) 양호 - Good" >> "$GOOD"
    echo -e "\033[0;32m[U-30] UMASK ${cur_umask_str} GOOD!!\033[0m"
else
    profile_umask=$(grep -v ^# "$file" 2>/dev/null | grep -E ^[[:space:]]*umask | awk {print } | tail -1)
    if [[ -z "$profile_umask" ]]; then
        echo "umask 022" >> "$file"
        echo "[U-30] UMASK 미설정 - /etc/profile 에 umask 022 추가" >> "$CHANGE"
        echo "[U-30] UMASK 미설정 → 022 추가 완료 - Good" >> "$GOOD"
        echo -e "\033[0;31m[U-30] UMASK 미설정 → 022 추가\033[0m"
    else
        prof_dec=$((8#${profile_umask}))
        if [[ "$prof_dec" -le "$UMASK_THRESHOLD" ]]; then
            echo "[U-30] /etc/profile umask ${profile_umask} (022 이하) 양호 - Good" >> "$GOOD"
            echo -e "\033[0;32m[U-30] /etc/profile umask ${profile_umask} GOOD!!\033[0m"
        else
            sed -i "s/^[[:space:]]*umask.*$/umask 022/" "$file"
            echo "[U-30] /etc/profile umask ${profile_umask} → 022 변경" >> "$CHANGE"
            echo "[U-30] umask ${profile_umask} → 022 변경 완료 - Good" >> "$GOOD"
            echo -e "\033[0;31m[U-30] umask ${profile_umask} → 022 변경\033[0m"
        fi
    fi
fi

echo "========== [U-30] end =========="
