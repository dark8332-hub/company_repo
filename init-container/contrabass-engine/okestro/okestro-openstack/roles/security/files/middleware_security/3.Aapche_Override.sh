#!/bin/bash
# 부모 스크립트(controller_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# WEB-06: Apache AllowOverride AuthConfig 설정 점검 및 조치
# AllowOverride None → AuthConfig 변경
# /var/www/html .htaccess 인증 설정 + 초기 계정 생성 (admin/cloud1234)

APACHE_CONF="/etc/apache2/apache2.conf"
HTPASSWD_FILE="/etc/apache2/.htpasswd"
HTACCESS_DIR="/var/www/html"
HTACCESS_FILE="${HTACCESS_DIR}/.htaccess"
INIT_USER="admin"
INIT_PASS="cloud1234"

echo "========== [3] Apache AllowOverride 점검 =========="

# Apache 프로세스 확인
if ! ps -ef | grep apache2 | grep -qv grep; then
    echo -e "\033[0;32m[3] Apache 미사용 - Good\033[0m"
    echo "[3] Apache: 미사용 - Good" >> "$GOOD"
    echo "========== [3] end =========="
    exit 0
fi

# AllowOverride None 라인 확인 (루트 디렉토리 블록 제외)
override_bad=$(awk '
    /^[[:space:]]*<Directory[[:space:]]+"\/">/ { skip=1 }
    /^[[:space:]]*<\/Directory>/               { skip=0 }
    !skip && /^[[:space:]]*AllowOverride[[:space:]]+None/ && !/^[[:space:]]*#/ { print NR": "$0 }
' "$APACHE_CONF")

if [[ -z "$override_bad" ]]; then
    echo -e "\033[0;32m[3] Apache AllowOverride 양호 - Good\033[0m"
    echo "[3] Apache AllowOverride: None 없음 (루트 제외) - Good" >> "$GOOD"
else
    echo -e "\033[0;31m[3] AllowOverride None 발견 → AuthConfig 로 변경\033[0m"

    # AllowOverride None → AuthConfig 변경 (루트 디렉토리 블록 제외)
    python3 - "$APACHE_CONF" << 'PYEOF'
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()
def replace_override(text):
    result, in_root_dir = [], False
    for line in text.splitlines(keepends=True):
        if re.match(r'\s*<Directory\s+"/">', line):
            in_root_dir = True
        if re.match(r'\s*</Directory>', line):
            in_root_dir = False
        if not in_root_dir:
            line = re.sub(r'(\bAllowOverride\s+)None', r'\1AuthConfig', line)
        result.append(line)
    return ''.join(result)
with open(path, 'w') as f:
    f.write(replace_override(content))
PYEOF

    {
        echo "[3] AllowOverride None → AuthConfig 변경"
        echo "  파일: $APACHE_CONF"
        echo "  변경 라인:"
        echo "$override_bad" | sed 's/^/    /'
    } >> "$CHANGE"

    # .htpasswd 초기 계정 생성
    htpasswd -bc "$HTPASSWD_FILE" "$INIT_USER" "$INIT_PASS" 2>/dev/null
    chmod 640 "$HTPASSWD_FILE"
    chown root:www-data "$HTPASSWD_FILE"
    {
        echo "  [.htpasswd 초기 계정 생성]"
        echo "  파일: $HTPASSWD_FILE"
        echo "  초기 계정 ID: $INIT_USER"
        echo "  초기 계정 PW: $INIT_PASS"
        echo "  ================================================================"
        echo "  !! 보안 주의: 초기 비밀번호($INIT_PASS)를 반드시 변경하세요 !!"
        echo "  비밀번호 변경 명령어:"
        echo "    htpasswd $HTPASSWD_FILE $INIT_USER"
        echo "  (새 비밀번호 입력 프롬프트가 표시됩니다)"
        echo "  ================================================================"
    } >> "$CHANGE"
    echo -e "\033[0;33m[3] .htpasswd 초기 계정 생성 완료 (admin/cloud1234) — 반드시 비밀번호 변경!\033[0m"

    # .htaccess 생성 (없을 경우만)
    if [[ ! -f "$HTACCESS_FILE" ]]; then
        mkdir -p "$HTACCESS_DIR"
        cat > "$HTACCESS_FILE" << 'HTEOF'
AuthName "Restricted Area"
AuthType Basic
AuthUserFile /etc/apache2/.htpasswd
Require valid-user
HTEOF
        chmod 644 "$HTACCESS_FILE"
        echo "  [.htaccess 생성] 파일: $HTACCESS_FILE" >> "$CHANGE"
        echo -e "\033[0;32m[3] .htaccess 생성 완료\033[0m"
    fi

    systemctl restart apache2
    echo "  Apache2 재시작 완료" >> "$CHANGE"
    echo -e "\033[0;32m[3] Apache2 재시작 완료\033[0m"

    echo "[3] AllowOverride None → AuthConfig 변경 및 .htaccess 설정 완료 - Good" >> "$GOOD"
fi

echo "========== [3] end =========="
