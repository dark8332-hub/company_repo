#!/bin/bash
# 5-3: NTP 및 시각 동기화 설정 여부 점검 (조치 안 함)
# chrony, ntp, ntpd, systemd-timesyncd 중 하나라도 active 이면 Good
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

echo "========== [U-65] NTP 시각 동기화 점검 =========="

ntp_active=""
ntp_svc=""

for svc in chrony ntp ntpd systemd-timesyncd; do
	status=$(systemctl is-active "$svc" 2>/dev/null)
	if [[ "$status" == "active" ]]; then
		ntp_active="$svc"
		ntp_svc="$svc"
		break
	fi
done

if [[ -n "$ntp_active" ]]; then
	echo -e "\033[0;32m[U-65] NTP 서비스 활성화 ($ntp_svc) Good!! \033[0m"
	echo "[U-65] NTP 시각 동기화: $ntp_svc 활성화 - Good" >> "$GOOD"
else
	echo -e "\033[0;31m[U-65] NTP 서비스 미설정 \033[0m"
	{
		echo "[U-65] NTP 시각 동기화: 미설정"
		echo "  사유: chrony, ntp, ntpd, systemd-timesyncd 중 활성화된 서비스가 없습니다."
		echo "  조치 필요: NTP 서비스를 직접 설치·활성화해 주세요."
		echo "  설치 명령(chrony): apt install chrony && systemctl enable --now chrony"
	} >> "$BAD"
fi

echo "========== [U-65] end =========="
