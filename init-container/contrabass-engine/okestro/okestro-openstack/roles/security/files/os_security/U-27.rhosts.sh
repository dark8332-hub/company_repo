#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# PDF U-27: $HOME/.rhosts, hosts.equiv 사용 금지
# 파일이 존재하면 소유자 및 권한 확인 (권한 600)
# 파일이 없으면 Good

FILES="/etc/hosts.equiv /root/.rhosts"

for file in $FILES; do
    if [[ ! -e "$file" ]]; then
        echo "[U-27] $file 파일 없음 - Good" >> "$GOOD"
        echo -e "\033[0;32m[U-27] $file not exists - Good!!\033[0m"
        continue
    fi

    issues=""
    perm_octal=$(stat -c "%a" "$file")
    owner=$(stat -c "%U" "$file")

    if [[ "$owner" != "root" ]]; then
        issues="${issues} 소유자(${owner}!=root)"
        chown root "$file"
        echo "[U-27] $file 소유자 root로 변경" >> "$CHANGE"
    fi

    if [[ "$perm_octal" -gt "600" ]]; then
        issues="${issues} 권한(${perm_octal}>600)"
        chmod 600 "$file"
        echo "[U-27] $file 권한 600으로 변경" >> "$CHANGE"
    fi

    if [[ -z "$issues" ]]; then
        echo "[U-27] $file 소유자 및 권한 양호 (owner=${owner}, perm=${perm_octal}) - Good" >> "$GOOD"
        echo -e "\033[0;32m[U-27] $file Good!!\033[0m"
    else
        echo "[U-27] $file 이상 감지: ${issues} - 자동 조치 완료" >> "$GOOD"
        echo -e "\033[0;31m[U-27] $file 이상: ${issues} - 조치 완료\033[0m"
    fi
done
