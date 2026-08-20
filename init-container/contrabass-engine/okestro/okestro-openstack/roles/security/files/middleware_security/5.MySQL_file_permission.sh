#!/bin/bash
# D-14: MySQL 설정 파일 접근 권한 점검 및 조치

if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

echo "========== [5] MySQL 설정 파일 권한 점검 =========="

TARGET="/etc/mysql/my.cnf"

if [[ ! -e "$TARGET" ]]; then
    echo -e "\033[0;31m[5] ${TARGET} 파일 없음 - 수동 확인 필요\033[0m"
    echo "[5] ${TARGET}: 파일 없음 - 수동 확인 필요" >> "$BAD"
    echo "========== [5] end =========="
    exit 0
fi

perm=$(stat -c "%a" "$TARGET")
owner=$(stat -c "%U" "$TARGET")
group=$(stat -c "%G" "$TARGET")
other_perm=$(( perm % 10 ))

if [[ "$other_perm" -gt 0 ]]; then
    echo -e "\033[0;31m[5] ${TARGET}: 권한 ${perm} → other 권한 존재 → 640으로 변경\033[0m"
    chmod 640 "$TARGET"
    chown root:mysql "$TARGET"
    echo "[5] ${TARGET}: 권한 ${perm} → 640, 소유 root:mysql 변경 완료" >> "$CHANGE"
    echo -e "\033[0;32m[5] ${TARGET}: 권한 640 변경 완료 - Good\033[0m"
    echo "[5] ${TARGET}: 권한 640, 소유 root:mysql - Good" >> "$GOOD"
else
    echo -e "\033[0;32m[5] ${TARGET}: 권한 ${perm} (${owner}:${group}) - Good\033[0m"
    echo "[5] ${TARGET}: 권한 ${perm} (${owner}:${group}) - Good" >> "$GOOD"
fi

echo "========== [5] end =========="
