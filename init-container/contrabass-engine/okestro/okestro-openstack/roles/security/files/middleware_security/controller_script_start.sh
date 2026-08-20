#!/bin/bash
# controller_script_start.sh
# ~/middleware-script/ 내 [0-9]*.sh 스크립트를 번호 순서대로 실행
# 결과: result_TS.txt / change_list.txt

cd "$(dirname "$0")"

TS=$(date +%y%m%d%H%M%S)
RESULT="./result_${TS}.txt"
export GOOD="/tmp/good_${TS}.txt"
export BAD="/tmp/bad_${TS}.txt"
export CHANGE="./change_list.txt"

> "$GOOD"
> "$BAD"

echo "============================================================"
echo "  Middleware (Apache) 취약점 점검 시작: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

sc_list=$(ls [0-9]*.sh 2>/dev/null | sort -t'.' -k1 -n)

if [[ -z "$sc_list" ]]; then
    echo "[오류] 실행할 스크립트가 없습니다."
    exit 1
fi

for sc in $sc_list; do
    echo ""
    echo ">>> 실행: $sc"
    bash "$sc"
done

echo ""
echo "============================================================"
echo "  점검 완료: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

# [숫자] 레이블 기준 고유 항목 수 집계
TOTAL_GOOD=$(grep -oE '\[[0-9]+\]' "$GOOD" 2>/dev/null | sort -u | wc -l)
TOTAL_BAD=$(grep  -oE '\[[0-9]+\]' "$BAD"  2>/dev/null | sort -u | wc -l)

{
    echo "============================================================"
    echo "  Middleware (Apache) 취약점 점검 결과"
    echo "  점검 일시: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================================"
    echo ""
    echo "[ 양호 항목: ${TOTAL_GOOD}건 ]"
    echo "------------------------------------------------------------"
    cat "$GOOD" 2>/dev/null
    echo ""
    echo "[ 취약 항목: ${TOTAL_BAD}건 ]"
    echo "------------------------------------------------------------"
    cat "$BAD" 2>/dev/null
    echo ""
    echo "[ 요약 ]"
    echo "  총 양호: ${TOTAL_GOOD}건 / 총 취약: ${TOTAL_BAD}건"
    echo "============================================================"
} > "$RESULT"

echo ""
echo "  결과 파일 : $RESULT"
echo "  변경 목록 : $CHANGE"
echo ""

rm -f "$GOOD" "$BAD"
