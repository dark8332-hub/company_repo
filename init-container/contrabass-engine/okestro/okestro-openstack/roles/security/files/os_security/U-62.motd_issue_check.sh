#!/bin/bash
# 1-62: 로그온 시 불필요 정보 차단·경고 메시지 점검 (조치 안 함, 판별만)
# 1) /etc/motd 파일 존재 여부
# 2) /etc/issue 에서 Ubuntu * LTS 라인 제외하고 다른 내용(경고 메시지 등) 있는지
# Good -> good_list_YYMMDDHHMMSS.txt, Bad -> bad_list_YYMMDDHHMMSS.txt, 변경 -> change_list_YYMMDDHHMMSS.txt

# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

echo "========== [U-62] motd / issue (warning message) check =========="

all_good=true

# Step 1: /etc/motd 존재 여부
if [[ -f /etc/motd ]]; then
	echo -e "\033[0;32m[U-62] /etc/motd exist Good!! \033[0m"
	echo "[U-62] /etc/motd: 파일 존재 확인 - Good" >> "$GOOD"
else
	echo -e "\033[0;31m[U-62] /etc/motd not exist. \033[0m"
	{
		echo "[U-62] /etc/motd: 파일 없음"
		echo "  사유: /etc/motd 파일이 존재하지 않습니다. 경고 메시지(예: 비인가 접근 금지 문구)를 직접 작성·추가해 주세요."
	} >> "$BAD"
	all_good=false
fi

# Step 2: /etc/issue — Ubuntu * LTS 라인 제외하고 다른 내용 있는지
if [[ ! -f /etc/issue ]]; then
	echo -e "\033[0;31m[U-62] /etc/issue not exist. \033[0m"
	{
		echo "[U-62] /etc/issue: 파일 없음"
		echo "  사유: /etc/issue 파일이 존재하지 않습니다. 경고 메시지를 직접 작성·추가해 주세요."
	} >> "$BAD"
	all_good=false
else
	other=$(grep -v -E 'Ubuntu [0-9]+\.[0-9]+(\.[0-9]+)? LTS|^[[:space:]]*$' /etc/issue 2>/dev/null \
		| sed 's/\\n//g;s/\\l//g;s/\\r//g;s/\\m//g;s/\\S//g;s/^[[:space:]]*//;s/[[:space:]]*$//' \
		| grep -v '^$')
	if [[ -n "$other" ]]; then
		echo -e "\033[0;32m[U-62] /etc/issue has warning message. Good!! \033[0m"
		echo "[U-62] /etc/issue: 버전 라인 외 경고 메시지 존재 확인 - Good" >> "$GOOD"
	else
		echo -e "\033[0;31m[U-62] /etc/issue has no warning message. \033[0m"
		{
			echo "[U-62] /etc/issue: 경고 메시지 없음 (버전 라인만 존재)"
			echo "  사유: /etc/issue 에 OS 버전 라인 외 경고 메시지가 없습니다. 비인가 접근 금지 등의 경고 문구를 직접 추가해 주세요."
		} >> "$BAD"
		all_good=false
	fi
fi

if $all_good; then
	echo "[U-62] motd/issue 경고 메시지: 모두 양호" >> "$GOOD"
fi

echo "========== [U-62] end =========="
