#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# PDF U-21: /etc/rsyslog.conf 파일 소유자 및 권한 설정
# 양호 기준: 소유자=root, 권한=640 이하

echo "========== [U-21] rsyslog.conf 소유자·권한 점검 =========="

FILE="/etc/rsyslog.conf"

if [[ ! -f "$FILE" ]]; then
    echo "[U-21] $FILE 파일 없음 - 점검 불가" >> "$BAD"
    echo -e "\033[0;31m[U-21] $FILE 파일 없음\033[0m"
    echo "========== [U-21] end =========="
    exit 0
fi

owner=$(stat -c "%U" "$FILE")
perm=$(stat -c "%a" "$FILE")
issues=""

if [[ "$owner" != "root" ]]; then
    issues="${issues} 소유자(${owner}!=root)"
    chown root "$FILE"
    echo "[U-21] $FILE 소유자 root로 변경" >> "$CHANGE"
fi

if [[ "$perm" -gt "640" ]]; then
    issues="${issues} 권한(${perm}>640)"
    chmod 640 "$FILE"
    echo "[U-21] $FILE 권한 640으로 변경" >> "$CHANGE"
fi

if [[ -z "$issues" ]]; then
    echo "[U-21] $FILE 소유자·권한 양호 (owner=root, perm=${perm}) - Good" >> "$GOOD"
    echo -e "\033[0;32m[U-21] $FILE Good!!\033[0m"
else
    echo "[U-21] $FILE 이상 감지: ${issues} - 자동 조치 완료 - Good" >> "$GOOD"
    echo -e "\033[0;31m[U-21] $FILE 이상: ${issues} - 조치 완료\033[0m"
fi

echo "========== [U-21] end =========="
