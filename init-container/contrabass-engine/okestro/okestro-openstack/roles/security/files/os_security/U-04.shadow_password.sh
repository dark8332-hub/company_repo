#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
# PDF U-04: 사용자 계정 비밀번호 암호화 저장 여부 점검
# /etc/passwd 두 번째 필드가 x인지 확인 (x = shadow 사용)
# x가 아니면 pwconv 로 shadow 비밀번호 적용

echo "========== shadow password check =========="

PASSWD="/etc/passwd"
bad=""
while IFS=: read -r user pass rest; do
    [[ -z "$user" ]] && continue
    [[ "$user" =~ ^# ]] && continue
    if [[ "$pass" != "x" ]]; then
        bad="$bad $user"
    fi
done < "$PASSWD"

if [[ -z "$bad" ]]; then
    echo "[U-04] /etc/passwd shadow 비밀번호 사용 양호 - Good" >> "$GOOD"
    echo -e "\033[0;32m/etc/passwd shadow in use Good!!\033[0m"
    echo "========== end =========="
    exit 0
fi

# 두 번째 필드가 x가 아닌 계정 있음 → pwconv 적용
echo -e "\033[0;31m평문 비밀번호 계정 발견 - pwconv 적용\033[0m"
if pwconv 2>/dev/null; then
    echo "[U-04] pwconv 적용 (shadow password 활성화)" >> "$CHANGE"
    echo "[U-04] pwconv 적용 완료 - Good" >> "$GOOD"
    echo -e "\033[0;32mpwconv done Good!!\033[0m"
else
    {
        echo "[U-04] pwconv 실패 - 수동 조치 필요"
        echo "  사유: /etc/passwd 에 평문 비밀번호 계정($bad) 존재"
        echo "  조치 필요: 수동으로 /etc/passwd, /etc/shadow 확인 후 pwconv 재실행"
    } >> "$BAD"
    echo -e "\033[0;33mpwconv failed\033[0m"
fi

echo "========== end =========="
