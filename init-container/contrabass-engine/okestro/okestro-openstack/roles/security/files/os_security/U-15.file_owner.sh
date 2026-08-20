#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# PDF U-15: 소유자 없는 파일/디렉토리 점검
# /proc, /sys, /dev, ceph/container 등 가상 FS 제외 (탐색 시간 절약)
SEARCH_DIRS="/root /home /tmp /var/tmp /etc /usr/local /var/www /srv /opt"

echo "========== [U-15] nouser / nogroup file check =========="

nouser_list=$(find $SEARCH_DIRS -nouser 2>/dev/null)
nogroup_list=$(find $SEARCH_DIRS -nogroup 2>/dev/null)

if [[ -z "$nouser_list" ]]; then
    echo -e "\033[0;32m[U-15] nouser 파일 없음 Good!!\033[0m"
    echo "[U-15] nouser: 해당 파일 없음 - Good" >> "$GOOD"
else
    nu_count=$(echo "$nouser_list" | grep -c .)
    echo -e "\033[0;31m[U-15] 소유자 없는 파일 ${nu_count}건 존재\033[0m"
    {
        echo "[U-15] 소유자 없는 파일(-nouser) 총 ${nu_count}건 (탐색 경로: $SEARCH_DIRS)"
        echo "$nouser_list" | head -10 | sed "s/^/  - /"
        echo "  사유: 시스템에 소유자가 없는 파일이 존재합니다."
        echo "  조치 필요: 담당자가 직접 확인 후 불필요하거나 소유자가 없는 파일은 chown <사용자> <파일경로> 로 소유자를 지정해 주세요."
    } >> "$BAD"
fi

if [[ -z "$nogroup_list" ]]; then
    echo -e "\033[0;32m[U-15] nogroup 파일 없음 Good!!\033[0m"
    echo "[U-15] nogroup: 해당 파일 없음 - Good" >> "$GOOD"
else
    ng_count=$(echo "$nogroup_list" | grep -c .)
    echo -e "\033[0;31m[U-15] 소유 그룹 없는 파일 ${ng_count}건 존재\033[0m"
    {
        echo "[U-15] 소유 그룹 없는 파일(-nogroup) 총 ${ng_count}건 (탐색 경로: $SEARCH_DIRS)"
        echo "$nogroup_list" | head -10 | sed "s/^/  - /"
        echo "  사유: 시스템에 소유 그룹이 없는 파일이 존재합니다."
        echo "  조치 필요: 담당자가 직접 확인 후 불필요하거나 소유 그룹이 없는 파일은 chgrp <그룹> <파일경로> 로 소유 그룹을 지정해 주세요."
    } >> "$BAD"
fi

echo "========== [U-15] end =========="
