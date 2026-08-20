#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
# [Debian] pam_faillock — common-auth, common-account에 있으면 유지, 없으면 추가 (순서 맞춤)
# common-auth: preauth, authfail, authsucc (audit deny=10 unlock_time=120)
# common-account: account required pam_faillock.so

echo "========== pam_faillock (common-auth, common-account) =========="

COMMON_AUTH="/etc/pam.d/common-auth"
COMMON_ACCOUNT="/etc/pam.d/common-account"

## ---- common-auth: preauth / authfail / authsucc (순서: preauth → pam_unix → authfail → authsucc) ----
if [[ -f "$COMMON_AUTH" ]]; then
	# preauth 없으면 pam_unix.so 앞에 추가
	if ! grep -q "pam_faillock.so.*preauth" "$COMMON_AUTH"; then
		ln=$(grep -n "pam_unix\.so" "$COMMON_AUTH" | grep -v '^#' | head -1 | cut -d: -f1)
		if [[ -n "$ln" ]]; then
			sed -i "${ln}i auth	required	pam_faillock.so	preauth	audit	deny=10	unlock_time=120" "$COMMON_AUTH"
			echo "[U-03] common-auth: pam_faillock preauth 추가" >> "$CHANGE"
		fi
	fi
	# authfail 없으면 pam_unix.so 다음에 추가
	if ! grep -q "pam_faillock.so.*authfail" "$COMMON_AUTH"; then
		ln=$(grep -n "pam_unix\.so" "$COMMON_AUTH" | grep -v '^#' | head -1 | cut -d: -f1)
		if [[ -n "$ln" ]]; then
			sed -i "$((ln+2))i auth	[default=die]	pam_faillock.so	authfail	audit	deny=10	unlock_time=120" "$COMMON_AUTH"
			echo "[U-03] common-auth: pam_faillock authfail 추가" >> "$CHANGE"
		fi
	fi
	# authsucc 없으면 authfail 다음에 추가
	if ! grep -q "pam_faillock.so.*authsucc" "$COMMON_AUTH"; then
		ln=$(grep -n "pam_faillock.so.*authfail" "$COMMON_AUTH" | head -1 | cut -d: -f1)
		if [[ -n "$ln" ]]; then
			sed -i "$((ln+1))i auth	sufficient	pam_faillock.so	authsucc	audit	deny=10	unlock_time=120" "$COMMON_AUTH"
			echo "[U-03] common-auth: pam_faillock authsucc 추가" >> "$CHANGE"
		fi
	fi
	# pam_unix 성공 시 authfail·authsucc·pam_deny 건너뛰기 (비밀번호 로그인 정상 동작)
	sed -i '/pam_unix\.so.*nullok/ s/\[success=1 default=ignore\]/[success=3 default=ignore]/; s/\[success=2 default=ignore\]/[success=3 default=ignore]/' "$COMMON_AUTH"
	echo -e "\033[0;32mcommon-auth Good!! \033[0m"
else
	echo "common-auth not found" >> "$BAD"
fi

## ---- common-account: account required pam_faillock.so ----
if [[ -f "$COMMON_ACCOUNT" ]]; then
	if ! grep -q "^[^#]*pam_faillock\.so" "$COMMON_ACCOUNT"; then
		ln=$(grep -n "^account\[" "$COMMON_ACCOUNT" | head -1 | cut -d: -f1)
		if [[ -n "$ln" ]]; then
			sed -i "${ln}i account	required	pam_faillock.so" "$COMMON_ACCOUNT"
		else
			sed -i "/^# here are the per-package/a account	required	pam_faillock.so" "$COMMON_ACCOUNT"
		fi
		echo "[U-03] common-account: pam_faillock.so 추가" >> "$CHANGE"
	fi
	echo -e "\033[0;32mcommon-account Good!! \033[0m"
else
	echo "common-account not found" >> "$BAD"
fi

echo "[U-03] 계정 잠금 임계값 점검 완료 - 위 항목별 결과 확인" >> "$GOOD"
echo "========== end =========="
