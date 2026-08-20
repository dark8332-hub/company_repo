#!/bin/bash
# OS 보안 취약점 점검·조치 메인 실행 스크립트
# U-xx 순서대로 실행, 결과를 result_TS.txt / change_list.txt 로 출력

# change_list.txt: 각 U-xx 스크립트에서 조치 시 "[U-XX] 조치 내용" 형식으로 한 줄씩 추가
cd "$(dirname "$0")"

TS=$(date +%y%m%d%H%M%S)
GOOD="./good_list_${TS}.txt"
BAD="./bad_list_${TS}.txt"
RESULT="./result_${TS}.txt"
CHANGE="./change_list.txt"

: > "$GOOD"
export GOOD BAD CHANGE
: > "$BAD"
: > "$CHANGE"

# U-xx 순서대로 정렬 실행
sc_list=$(ls U-*.sh 2>/dev/null | sort -t'-' -k2 -V)

for i in $sc_list; do
    echo "======================================== start $i ========================================"

    lc_g=$(wc -l < "$GOOD" 2>/dev/null || echo 0)
    lc_b=$(wc -l < "$BAD"  2>/dev/null || echo 0)
    lc_c=$(wc -l < "$CHANGE" 2>/dev/null || echo 0)

    bash "./$i"

    new_good=$(tail -n +$((lc_g+1)) "$GOOD" 2>/dev/null)
    new_bad=$(tail -n +$((lc_b+1)) "$BAD" 2>/dev/null)
    new_change=$(tail -n +$((lc_c+1)) "$CHANGE" 2>/dev/null)

    if [[ -z "$new_good" && -z "$new_bad" && -z "$new_change" ]]; then
        echo "[${i%.sh}] 변경 없음 - Good" >> "$GOOD"
    fi

    echo -e "======================================== end $i ========================================\n"
done

# ──────────────────────────────────────────────
# result_TS.txt 생성: Good / Bad 통합 리포트
# ──────────────────────────────────────────────
# [U-xx] 레이블 기준 고유 항목 수 (중복 제거)
TOTAL_GOOD=$(grep -oE '\[U-[0-9]+' "$GOOD" 2>/dev/null | sort -u | wc -l)
TOTAL_BAD=$(grep -oE '\[U-[0-9]+' "$BAD"  2>/dev/null | sort -u | wc -l)

{
echo "============================================================"
echo "  OS 보안 취약점 점검 결과 리포트"
echo "  실행 일시 : $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""
echo "[ 요약 ]"
echo "  양호(Good) 항목 수 : ${TOTAL_GOOD}"
echo "  취약(Bad)  항목 수 : ${TOTAL_BAD}"
echo ""
echo "============================================================"
echo "  [GOOD] 양호 항목 목록"
echo "============================================================"
if [[ -s "$GOOD" ]]; then
    while IFS= read -r line; do
        echo "  ✔ $line"
    done < "$GOOD"
else
    echo "  (없음)"
fi
echo ""
echo "============================================================"
echo "  [BAD] 취약 항목 목록"
echo "============================================================"
if [[ -s "$BAD" ]]; then
    while IFS= read -r line; do
        echo "  ✘ $line"
    done < "$BAD"
else
    echo "  (없음)"
fi
echo ""
echo "============================================================"
echo "  상세 변경 내역 : ./change_list.txt 참고"
echo "============================================================"
} > "$RESULT"

# good_list / bad_list 임시 파일 삭제
rm -f "$GOOD" "$BAD"

echo ""
echo "===== 실행 완료 ====="
echo "결과  : $RESULT"
echo "변경  : $CHANGE"
cat "$RESULT"
