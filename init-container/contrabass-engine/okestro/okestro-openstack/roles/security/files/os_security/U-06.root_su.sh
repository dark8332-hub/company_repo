# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
group_list=$(cat /etc/group | grep wheel)

if [[ "$group_list" == "" ]]; then
    echo -e "\033[0;31m[U-06] wheel 그룹 없음 - 생성 조치\033[0m"
    groupadd wheel
    usermod -aG wheel ubuntu
    echo "[U-06] wheel 그룹 생성" >> "$CHANGE"
    echo "[U-06] ubuntu 계정을 wheel 그룹에 추가" >> "$CHANGE"
    echo "[U-06] wheel 그룹 생성 완료 - Good" >> "$GOOD"
else
    echo -e "\033[0;32m[U-06] wheel 그룹 존재 양호\033[0m"
    echo "[U-06] wheel 그룹 존재 양호 - Good" >> "$GOOD"
fi

if ! grep -q 'pam_wheel' /etc/pam.d/su 2>/dev/null; then
    echo -e "\033[0;31m[U-06] pam_wheel.so 미설정 - 추가 조치\033[0m"
    echo 'auth required pam_wheel.so group=wheel' >> /etc/pam.d/su
    usermod -aG wheel ubuntu
    echo "[U-06] /etc/pam.d/su: pam_wheel.so group=wheel 추가" >> "$CHANGE"
    echo "[U-06] ubuntu 계정을 wheel 그룹에 추가" >> "$CHANGE"
    echo "[U-06] pam_wheel.so 추가 완료 - Good" >> "$GOOD"
else
    echo -e "\033[0;32m[U-06] pam_wheel.so 설정 양호\033[0m"
    echo "[U-06] pam_wheel.so 설정 양호 - Good" >> "$GOOD"
fi
