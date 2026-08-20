# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
allow_check=$(grep -Ev '^[[:space:]]*#|^[[:space:]]*$' /etc/hosts.allow 2>/dev/null)

if [ -z "$allow_check" ]; then
    echo -e "\033[0;31mFAIL: /etc/hosts.allow 에 활성 허용 규칙 없음 - hosts.deny 변경 중단\033[0m"
    {
        echo "[U-28] /etc/hosts.allow 활성 규칙 없음 - 조치 중단"
        echo "  사유: hosts.allow 에 허용 규칙이 없어 hosts.deny ALL:ALL 설정 시 SSH 접속 차단 위험"
        echo "  조치 필요: hosts.allow 에 관리 IP 허용 규칙 설정 후 재점검 필요"
    } >> "$BAD"
    exit 1
fi

echo "[U-28] /etc/hosts.allow 활성 규칙 존재 양호 - Good" >> "$GOOD"
echo -e "\033[0;32m/etc/hosts.allow 활성 규칙 확인 완료\033[0m"

deny_check=$(grep -Ev '^[[:space:]]*#|^[[:space:]]*$' /etc/hosts.deny 2>/dev/null | grep '^ALL:ALL$')

if [ -n "$deny_check" ]; then
    echo "[U-28] /etc/hosts.deny ALL:ALL 설정 양호 - Good" >> "$GOOD"
    echo -e "\033[0;32m/etc/hosts.deny ALL:ALL Good!!\033[0m"
else
    echo -e "\033[0;31m/etc/hosts.deny ALL:ALL 미설정 - 추가 조치\033[0m"
    echo "ALL:ALL" >> /etc/hosts.deny
    echo "[U-28] /etc/hosts.deny ALL:ALL 추가" >> "$CHANGE"
    echo "[U-28] /etc/hosts.deny ALL:ALL 추가 완료 - Good" >> "$GOOD"
fi
