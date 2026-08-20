# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
check_sshd=$(cat /etc/ssh/sshd_config | grep -i permitrootlogin | grep -v "#")
check_file=/etc/ssh/sshd_config

if [[ "$check_sshd" == *"yes"* ]]; then
    echo -e "\033[0;31m[U-01] PermitRootLogin yes — 취약 상태. 자동 조치하지 않음. 관리자가 수동으로 조치하세요.\033[0m"
    echo "[U-01] /etc/ssh/sshd_config PermitRootLogin yes 감지 — 자동 변경 미실행. 관리자 수동 조치" >> "$BAD"
    echo "  - PermitRootLogin 을 no 로 변경" >> "$BAD"
    echo "  - 적용: systemctl restart ssh " >> "$BAD"
    echo "  - Ceph Cluster node일 경우 예외처리 해야할 수 있습니다.  " >> "$BAD"
    echo "[U-01] PermitRootLogin yes — 관리자 수동 조치 필요 (자동 변경·서비스 재시작 없음)" >> "$CHANGE"
else
    echo "[U-01] PermitRootLogin 설정 양호 - Good" >> "$GOOD"
    echo -e "\033[0;32mPermitRootLogin GOOD!!\033[0m"
fi

