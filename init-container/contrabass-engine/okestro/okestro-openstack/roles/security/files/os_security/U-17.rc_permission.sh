#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
# 1-17: 시스템 시작 스크립트 파일 권한 적절성 점검
# /etc/rc.local (파일), /etc/rc.d (디렉터리) 존재 시 chown root, chmod o-w 적용
# good=change_list, bad=un_change_list

echo "========== rc.local / rc.d permission check =========="

targets="/etc/rc.local /etc/rc.d"
for t in $targets; do
	if [[ -e "$t" ]]; then
		cur_perm=$(stat -c %a "$t" 2>/dev/null)
		cur_owner=$(stat -c %U "$t" 2>/dev/null)
		need_fix=""
		[[ "$cur_owner" != "root" ]] && need_fix="Y"
		[[ "$cur_perm" =~ [2-7]$ ]] && need_fix="Y"
		if [[ -n "$need_fix" ]]; then
			chown root "$t"
			chmod o-w "$t"
			echo "[U-17] $t 소유자 root, 권한 o-w 적용" >> "$CHANGE"
			echo "[U-17] $t 소유자·권한 이상 - 조치 완료 - Good" >> "$GOOD"
			echo -e "\033[0;31mApplied chown root, chmod o-w: $t \033[0m"
		fi
		echo "[U-17] $t 소유자 및 권한 양호 - Good" >> "$GOOD"
		echo -e "\033[0;32m$t Good!! \033[0m"
	else
		echo "[U-17] $t 없음 - Good" >> "$GOOD"
		echo -e "\033[0;32m$t not exist Good!! \033[0m"
	fi
done

echo "========== end =========="
