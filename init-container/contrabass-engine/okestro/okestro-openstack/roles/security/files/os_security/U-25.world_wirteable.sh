#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# PDF U-25: world writable 파일 점검 (조치 안 함)
# /proc, /sys, /dev, ceph/cgroup/container 등 가상 FS 제외
SEARCH_DIRS="/root /home /tmp /var/tmp /etc /usr/local /var/www /srv /opt"

echo "========== [U-25] World Writable file check =========="

ww_list=$(find $SEARCH_DIRS -perm -002 -not -type l 2>/dev/null)
ww_count=$(echo "$ww_list" | grep -c . 2>/dev/null || echo 0)

if [[ -z "$ww_list" ]]; then
    echo -e "\033[0;32m[U-25] World Writable 파일 없음 Good!!\033[0m"
    echo "[U-25] World Writable: 해당 파일 없음 - Good" >> "$GOOD"
else
    echo -e "\033[0;31m[U-25] World Writable 파일 ${ww_count}건 존재\033[0m"
    {
        echo "[U-25] World Writable 파일 총 ${ww_count}건 존재"
        echo "  탐색 경로: $SEARCH_DIRS"
        echo "  사유: others 쓰기 권한이 설정된 파일이 존재합니다."
        echo "  조치 필요: 담당자가 직접 확인 후 불필요한 파일은 chmod o-w 로 권한을 제거해 주세요."
        echo "  (주요 파일 목록 - 최대 10건)"
        echo "$ww_list" | head -10 | sed "s/^/    - /"
    } >> "$BAD"
fi

echo "========== [U-25] end =========="
