#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

SEARCH_DIRS="/root /home /tmp /var/tmp /etc /usr/local/bin /usr/local/sbin"

echo "========== [U-33] 숨김 파일·디렉토리 점검 =========="

hide_list=$(find $SEARCH_DIRS -name ".*" 2>/dev/null)
hide_count=$(echo "$hide_list" | grep -c . 2>/dev/null || echo 0)

if [[ -z "$hide_list" ]]; then
    echo -e "\033[0;32m[U-33] 숨김 파일·디렉토리 없음 Good!!\033[0m"
    echo "[U-33] 숨김 파일·디렉토리: 없음 - Good" >> "$GOOD"
else
    echo -e "\033[0;31m[U-33] 숨김 파일·디렉토리 ${hide_count}건 존재\033[0m"
    {
        echo "[U-33] 숨김 파일·디렉토리 총 ${hide_count}건 존재 (탐색 경로: $SEARCH_DIRS)"
        echo "  사유: 주요 경로에 숨김 파일(. 으로 시작)이 존재합니다."
        echo "  조치 필요: 불필요하거나 의심스러운 파일은 담당자와 협의 후 직접 삭제해 주세요."
        echo "  (주요 파일 목록 - 최대 10건)"
        echo "$hide_list" | head -10 | sed "s/^/    - /"
    } >> "$BAD"
fi

echo "========== [U-33] end =========="
