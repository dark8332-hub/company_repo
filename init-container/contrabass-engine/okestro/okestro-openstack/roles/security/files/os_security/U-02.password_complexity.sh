#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
# [Debian] 패스워드 복잡도 - 한국인터넷진흥원 가이드 (아래 3단계만)
# Step1: /etc/security/pwquality.conf
# Step2: /etc/pam.d/common-password — pam_pwquality.so, pam_pwhistory.so(remember=4 이상) 가 pam_unix.so 위에
# Step3: /etc/login.defs — PASS_MAX_DAYS 90, PASS_MIN_DAYS 1
# good=change_list, bad=un_change_list

echo "========== password complexity check =========="

## Step 1: /etc/security/pwquality.conf
PWQUALITY_CONF="/etc/security/pwquality.conf"
if [[ ! -f "$PWQUALITY_CONF" ]]; then
	mkdir -p /etc/security
	touch "$PWQUALITY_CONF"
	echo "[U-02] /etc/security/pwquality.conf 파일 생성" >> "$CHANGE"
fi
set_pwquality_value() {
	local key="$1" val="$2"
	if grep -q "^[[:space:]]*${key}[[:space:]]*=" "$PWQUALITY_CONF" 2>/dev/null; then
		sed -i "s/^[[:space:]]*${key}[[:space:]]*=.*/${key} = ${val}/" "$PWQUALITY_CONF"
		echo "[U-02] /etc/security/pwquality.conf ${key} 설정 변경" >> "$CHANGE"
	else
		echo "${key} = ${val}" >> "$PWQUALITY_CONF"
		echo "[U-02] /etc/security/pwquality.conf ${key} 설정 추가" >> "$CHANGE"
	fi
}
for kv in "minlen:8" "dcredit:-1" "ucredit:-1" "lcredit:-1" "ocredit:-1"; do
	k="${kv%%:*}" v="${kv##*:}"
	set_pwquality_value "$k" "$v"
done
if ! grep -qE '^[^#]*\benforce_for_root\b' "$PWQUALITY_CONF" 2>/dev/null; then
	echo "enforce_for_root" >> "$PWQUALITY_CONF"
	echo "[U-02] /etc/security/pwquality.conf enforce_for_root 추가" >> "$CHANGE"
fi
echo -e "\033[0;32mpwquality.conf Good!! \033[0m"

## Step 2: common-password — pam_pwquality.so, pam_pwhistory.so(remember=4 이상) above pam_unix.so
COMMON_PW="/etc/pam.d/common-password"
if [[ -f "$COMMON_PW" ]]; then
	ln_pwq=$(grep -n "pam_pwquality\.so" "$COMMON_PW" | head -1 | cut -d: -f1)
	ln_unix=$(grep -n "pam_unix\.so" "$COMMON_PW" | head -1 | cut -d: -f1)
	if [[ -n "$ln_pwq" && -n "$ln_unix" && "$ln_pwq" -gt "$ln_unix" ]]; then
		echo "common-password: pam_pwquality must be above pam_unix. Reorder manually." >> "$BAD"
		echo -e "\033[0;31mpam_pwquality.so should be above pam_unix.so \033[0m"
	else
		echo -e "\033[0;32mcommon-password module order Good!! \033[0m"
	fi
	# 최근 비밀번호 기억 4회 이상: pam_pwhistory.so remember=4
	if grep -q "pam_pwhistory\.so" "$COMMON_PW"; then
		cur_remember=$(grep "pam_pwhistory\.so" "$COMMON_PW" | grep -oE 'remember=[0-9]+' | head -1 | cut -d= -f2)
		if [[ -n "$cur_remember" && "$cur_remember" -ge 4 ]]; then
			echo -e "\033[0;32mpam_pwhistory remember>=4 Good!! \033[0m"
		else
			if [[ -n "$cur_remember" ]]; then
				sed -i '/pam_pwhistory\.so/ s/remember=[0-9]*/remember=4/g' "$COMMON_PW"
			else
				sed -i '/pam_pwhistory\.so/ s/$/ remember=4/' "$COMMON_PW"
			fi
			echo "[U-02] common-password: pam_pwhistory.so remember=4 추가" >> "$CHANGE"
			echo -e "\033[0;31mpam_pwhistory remember set to 4 \033[0m"
		fi
	else
		ln_u=$(grep -n "pam_unix\.so" "$COMMON_PW" | head -1 | cut -d: -f1)
		if [[ -n "$ln_u" ]]; then
			sed -i "${ln_u}i password	required	pam_pwhistory.so	remember=4" "$COMMON_PW"
			echo "[U-02] common-password: pam_pwhistory.so remember=4 추가" >> "$CHANGE"
			echo -e "\033[0;31madded pam_pwhistory.so remember=4 \033[0m"
		else
			echo "common-password: pam_unix not found, skip pwhistory" >> "$BAD"
		fi
	fi
else
	echo "common-password not found" >> "$BAD"
fi

## Step 3: /etc/login.defs — PASS_MAX_DAYS 90, PASS_MIN_DAYS 1
LOGIN_DEFS="/etc/login.defs"
if [[ -f "$LOGIN_DEFS" ]]; then
	if grep -q "^[[:space:]]*PASS_MAX_DAYS[[:space:]]" "$LOGIN_DEFS"; then
		sed -i 's/^[[:space:]]*PASS_MAX_DAYS[[:space:]].*/PASS_MAX_DAYS\t90/' "$LOGIN_DEFS"
		echo "[U-02] /etc/login.defs PASS_MAX_DAYS 90 설정" >> "$CHANGE"
	else
		echo -e "PASS_MAX_DAYS\t90" >> "$LOGIN_DEFS"
		echo "[U-02] /etc/login.defs PASS_MAX_DAYS 90 설정" >> "$CHANGE"
	fi
	if grep -q "^[[:space:]]*PASS_MIN_DAYS[[:space:]]" "$LOGIN_DEFS"; then
		sed -i 's/^[[:space:]]*PASS_MIN_DAYS[[:space:]].*/PASS_MIN_DAYS\t1/' "$LOGIN_DEFS"
		echo "[U-02] /etc/login.defs PASS_MIN_DAYS 1 설정" >> "$CHANGE"
	else
		echo -e "PASS_MIN_DAYS\t1" >> "$LOGIN_DEFS"
		echo "[U-02] /etc/login.defs PASS_MIN_DAYS 1 설정" >> "$CHANGE"
	fi
	echo -e "\033[0;32mlogin.defs Good!! \033[0m"
else
	echo "login.defs not found" >> "$BAD"
fi

echo "[U-02] 비밀번호 관리정책 점검 완료 - 위 항목별 결과 확인" >> "$GOOD"
echo "========== end password complexity =========="
