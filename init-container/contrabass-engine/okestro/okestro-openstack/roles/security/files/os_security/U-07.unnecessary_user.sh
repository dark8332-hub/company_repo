#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# PDF U-07: 불필요한 계정 존재 여부 점검 (조치 안 함)
# ※ 자동 삭제하지 않음 - 담당자가 직접 확인 후 제거

UNNECESSARY_ACCOUNTS="adm lp sync shutdown halt news uucp operator games gopher nfsnobody squid"
un_list=""

for i in $UNNECESSARY_ACCOUNTS; do
    if grep -q "^${i}:" /etc/passwd; then
        un_list="$un_list $i"
    fi
done

if [[ -z "$un_list" ]]; then
    echo "[U-07] 불필요한 계정 없음 - Good" >> "$GOOD"
    echo -e "\033[0;32m[U-07] Unnecessary user check Good!!\033[0m"
else
    echo -e "\033[0;31m[U-07] 불필요한 계정 발견: $un_list\033[0m"
    {
        echo "[U-07] 불필요한 계정 발견"
        echo "  계정 목록: $un_list"
        echo "  사유: /etc/passwd 에 불필요한 기본 계정이 존재합니다."
        echo "  조치 필요: 담당자가 직접 확인 후 아래 명령으로 제거해 주세요."
        echo "  제거 명령: userdel <계정명>"
        echo "  ※ /etc/passwd 에서 # 주석 처리는 실제 계정 제거가 아니므로 반드시 userdel 사용"
    } >> "$BAD"
fi
