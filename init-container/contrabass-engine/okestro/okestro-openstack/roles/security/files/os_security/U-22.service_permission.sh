#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# PDF U-22: /etc/services 파일 소유자 및 권한 설정
# 대상: /etc/services 파일 (권한 644, 소유자 root)

file="/etc/services"
issues=""

if [[ ! -e "$file" ]]; then
    echo "[U-22] $file 파일 없음 - 점검 불가" >> "$BAD"
    exit 1
fi

perm_octal=$(stat -c "%a" "$file")
owner=$(stat -c "%U" "$file")

if [[ "$owner" != "root" ]]; then
    issues="${issues} 소유자(${owner}!=root)"
    chown root "$file"
    echo "[U-22] $file 소유자 root로 변경" >> "$CHANGE"
fi

if [[ "$perm_octal" -gt "644" ]]; then
    issues="${issues} 권한(${perm_octal}>644)"
    chmod 644 "$file"
    echo "[U-22] $file 권한 644로 변경" >> "$CHANGE"
fi

if [[ -z "$issues" ]]; then
    echo "[U-22] /etc/services 소유자 및 권한 양호 (owner=root, perm=${perm_octal}) - Good" >> "$GOOD"
    echo -e "\033[0;32m[U-22] /etc/services permission Good!!\033[0m"
else
    echo "[U-22] /etc/services 이상 감지: ${issues} - 자동 조치 완료" >> "$GOOD"
    echo -e "\033[0;31m[U-22] /etc/services 이상 감지: ${issues} - 조치 완료\033[0m"
fi
