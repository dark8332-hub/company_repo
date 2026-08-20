#!/bin/bash
# D-21: MySQL GRANT OPTION 사용 제한

if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

MYSQL_CMD="mysql -uroot"

echo "========== [6] MySQL GRANT OPTION 권한 점검 =========="

if ! systemctl is-active --quiet mysql; then
    echo -e "\033[0;32m[6] MySQL 미사용 - Good\033[0m"
    echo "[6] MySQL: 미사용 - Good" >> "$GOOD"
    echo "========== [6] end =========="
    exit 0
fi

# root, 내부 시스템 계정 제외하고 GRANT OPTION 보유 계정 확인
grant_bad=$($MYSQL_CMD -e "SELECT user, host FROM mysql.user
WHERE grant_priv = 'Y'
AND user NOT IN ('root')
AND user NOT LIKE 'mysql.%'
AND user NOT LIKE 'percona.%';" 2>/dev/null | tail -n +2)

# root의 GRANT OPTION은 정상이므로 별도 확인
root_grant=$($MYSQL_CMD -e "SELECT user, host FROM mysql.user
WHERE grant_priv = 'Y' AND user = 'root';" 2>/dev/null | tail -n +2)

# Percona PXC 내부 계정 GRANT OPTION 확인 (pxc.internal.session, pxc.sst.role)
pxc_grant=$($MYSQL_CMD -e "SELECT user, host FROM mysql.user
WHERE grant_priv = 'Y' AND (user LIKE 'mysql.pxc%');" 2>/dev/null | tail -n +2)

if [[ -z "$grant_bad" ]]; then
    echo -e "\033[0;32m[6] 일반 계정의 GRANT OPTION 없음 - Good\033[0m"
    echo "[6] MySQL GRANT OPTION: 일반 계정에 GRANT OPTION 없음 - Good" >> "$GOOD"
    if [[ -n "$pxc_grant" ]]; then
        echo -e "\033[0;32m[6] PXC 내부 계정(mysql.pxc.*)의 GRANT OPTION은 Percona Cluster 운영상 정상 - Good\033[0m"
        echo "[6] MySQL GRANT OPTION: PXC 내부 계정 GRANT OPTION - 클러스터 운영용 정상 - Good" >> "$GOOD"
    fi
else
    echo -e "\033[0;31m[6] GRANT OPTION 보유 일반 계정 발견\033[0m"
    echo "[6] MySQL GRANT OPTION: 일반 계정 GRANT OPTION 보유 - Bad" >> "$BAD"

    while IFS=$'\t' read -r user host; do
        [[ -z "$user" ]] && continue
        echo -e "  \033[0;31m취약: ${user}@${host} → GRANT OPTION 보유\033[0m"
        echo "    ✘ ${user}@${host}: GRANT OPTION 보유" >> "$BAD"

        # GRANT OPTION 회수
        $MYSQL_CMD -e "REVOKE GRANT OPTION ON *.* FROM '${user}'@'${host}';" 2>/dev/null
        $MYSQL_CMD -e "FLUSH PRIVILEGES;" 2>/dev/null
        echo "[6] ${user}@${host}: GRANT OPTION 회수 완료" >> "$CHANGE"
        echo -e "\033[0;32m[6] ${user}@${host}: GRANT OPTION 회수 완료 - Good\033[0m"
    done <<< "$grant_bad"

    echo "[6] MySQL GRANT OPTION: 회수 처리 완료 - Good" >> "$GOOD"
fi

echo "========== [6] end =========="
