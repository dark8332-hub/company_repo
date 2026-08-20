#!/bin/bash
# 부모 스크립트(controller_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# [4] Apache 서버 헤더 정보 노출 제한 점검 및 조치
# 점검 파일 우선순위: security.conf(conf-enabled) > apache2.conf
# 양호 기준: ServerTokens Prod, ServerSignature Off

SECURITY_CONF="/etc/apache2/conf-available/security.conf"
APACHE_CONF="/etc/apache2/apache2.conf"

echo "========== [4] Apache 서버 헤더 정보 노출 점검 =========="

# Apache 프로세스 확인
if ! ps -ef | grep apache2 | grep -qv grep; then
    echo -e "\033[0;32m[4] Apache 미사용 - Good\033[0m"
    echo "[4] Apache: 미사용 - Good" >> "$GOOD"
    echo "========== [4] end =========="
    exit 0
fi

issues=""

# ── security.conf 점검 (conf-enabled에 있으므로 apache2.conf보다 우선 적용됨) ──
tokens_val=$(grep -E "^\s*ServerTokens\s+" "$SECURITY_CONF" 2>/dev/null | grep -v "^#" | awk '{print $2}' | tail -1)
sig_val=$(grep -E "^\s*ServerSignature\s+" "$SECURITY_CONF" 2>/dev/null | grep -v "^#" | awk '{print $2}' | tail -1)

echo "[4] security.conf 현재값: ServerTokens=${tokens_val:-없음}, ServerSignature=${sig_val:-없음}"

# ServerTokens 점검
if [[ "$tokens_val" != "Prod" ]]; then
    issues="${issues} ServerTokens(${tokens_val:-없음}→Prod)"
    # 기존 설정값 주석처리 후 Prod로 교체
    sed -i "s|^\s*ServerTokens\s\+.*|#&\nServerTokens Prod|" "$SECURITY_CONF"
    echo "[4] security.conf ServerTokens ${tokens_val} → Prod 변경" >> "$CHANGE"
fi

# ServerSignature 점검
if [[ "$sig_val" != "Off" ]]; then
    issues="${issues} ServerSignature(${sig_val:-없음}→Off)"
    sed -i "s|^\s*ServerSignature\s\+.*|#&\nServerSignature Off|" "$SECURITY_CONF"
    echo "[4] security.conf ServerSignature ${sig_val} → Off 변경" >> "$CHANGE"
fi

if [[ -z "$issues" ]]; then
    echo -e "\033[0;32m[4] ServerTokens=Prod, ServerSignature=Off 양호 - Good\033[0m"
    echo "[4] Apache 헤더 정보 노출 제한: ServerTokens=Prod, ServerSignature=Off - Good" >> "$GOOD"
else
    systemctl reload apache2
    echo "  Apache reload 완료" >> "$CHANGE"
    echo -e "\033[0;32m[4] 조치 완료 (${issues}) - Good\033[0m"
    echo "[4] Apache 헤더 정보 노출 제한: 조치 완료 (${issues}) - Good" >> "$GOOD"
fi

echo "========== [4] end =========="
