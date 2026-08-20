#!/bin/bash
# 부모 스크립트(controller_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# [1] Apache DocumentRoot 기본 경로 분리 점검 및 조치
# 기본 경로(/var/www/html) 사용 시 /srv/www/html 로 변경

SITES_CONF="/etc/apache2/sites-available/000-default.conf"
DEFAULT_ROOT="/var/www/html"
NEW_ROOT="/srv/www/html"

echo "========== [1] Apache DocumentRoot 경로 설정 점검 =========="

if ! ps -ef | grep apache2 | grep -qv grep; then
    echo -e "\033[0;32m[1] Apache 미사용 - Good\033[0m"
    echo "[1] Apache: 미사용 - Good" >> "$GOOD"
    echo "========== [1] end =========="
    exit 0
fi

current_root=$(grep -m1 "^\s*DocumentRoot" "$SITES_CONF" 2>/dev/null | awk '{print $2}')

if [[ -z "$current_root" ]]; then
    echo -e "\033[0;31m[1] DocumentRoot 설정 없음 - 수동 확인 필요\033[0m"
    echo "[1] DocumentRoot 설정 없음 - 수동 확인 필요" >> "$BAD"
    echo "========== [1] end =========="
    exit 0
fi

if [[ "$current_root" != "$DEFAULT_ROOT" ]]; then
    echo -e "\033[0;32m[1] DocumentRoot 기본 경로 아님 ($current_root) - Good\033[0m"
    echo "[1] DocumentRoot: $current_root (기본 경로 아님) - Good" >> "$GOOD"
else
    echo -e "\033[0;31m[1] DocumentRoot 기본 경로($DEFAULT_ROOT) 사용 중 → $NEW_ROOT 으로 변경\033[0m"

    mkdir -p "$NEW_ROOT"

    sed -i "s|DocumentRoot ${DEFAULT_ROOT}|DocumentRoot ${NEW_ROOT}|g" "$SITES_CONF"
    sed -i "s|<Directory ${DEFAULT_ROOT}>|<Directory ${NEW_ROOT}>|g" "$SITES_CONF"
    sed -i "s|<Directory \"${DEFAULT_ROOT}\">|<Directory \"${NEW_ROOT}\">|g" "$SITES_CONF"

    systemctl reload apache2

    {
        echo "[1] DocumentRoot 변경: $DEFAULT_ROOT → $NEW_ROOT"
        echo "  파일: $SITES_CONF"
        echo "  Apache reload 완료"
        echo "  ※ OpenStack API VirtualHost(keystone/masakari/placement)는 별도 포트로 운영 — 영향 없음"
    } >> "$CHANGE"

    echo -e "\033[0;32m[1] DocumentRoot 변경 완료 ($DEFAULT_ROOT → $NEW_ROOT) - Good\033[0m"
    echo "[1] DocumentRoot: $DEFAULT_ROOT → $NEW_ROOT 변경 완료 - Good" >> "$GOOD"
fi

echo "========== [1] end =========="
