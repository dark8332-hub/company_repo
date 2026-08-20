#!/bin/bash
# 1-63: /etc/sudoers 파일 소유자 및 권한 점검·조치
# 소유자: root, 권한: 640
# Good -> good_list_TS.txt, Bad/조치 -> bad_list_TS.txt / change_list_TS.txt

# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

TARGET="/etc/sudoers"

echo "========== [U-63] /etc/sudoers permission check =========="

if [[ ! -f "$TARGET" ]]; then
	echo -e "\033[0;31m[U-63] /etc/sudoers 파일이 존재하지 않습니다. \033[0m"
	{
		echo "[U-63] /etc/sudoers: 파일 없음"
		echo "  사유: /etc/sudoers 파일이 존재하지 않습니다. 직접 확인해 주세요."
	} >> "$BAD"
	echo "========== [U-63] end =========="
	exit 0
fi

owner=$(stat -c "%U" "$TARGET")
perm=$(stat -c "%a" "$TARGET")

need_fix=false

# 소유자 확인
if [[ "$owner" != "root" ]]; then
	echo -e "\033[0;31m[U-63] 소유자 불량: $owner (root 여야 함) \033[0m"
	need_fix=true
fi

# 권한 확인 (640 이하인지: 640보다 큰 권한이면 bad)
# 허용: 600, 400, 440, 640 등 / 불허: 644, 664, 666, 777 등
if [[ "$((8#$perm & 8#007))" -ne 0 ]] || [[ "$((8#$perm & 8#020))" -ne 0 ]] || [[ "$((8#$perm & 8#040))" -ne 0 && "$((8#$perm & 8#004))" -ne 0 ]]; then
	# others 권한 있거나, group write 있으면 bad
	need_fix=true
fi
# 단순하게: 640 초과(other 읽기·쓰기 또는 group 쓰기)면 조치
if [[ $((8#$perm)) -gt $((8#640)) ]]; then
	need_fix=true
fi

if $need_fix; then
	before_owner="$owner"
	before_perm="$perm"

	chown root "$TARGET"
	chmod 640 "$TARGET"

	after_owner=$(stat -c "%U" "$TARGET")
	after_perm=$(stat -c "%a" "$TARGET")

	echo -e "\033[0;32m[U-63] 조치 완료: 소유자 $before_owner->$after_owner, 권한 $before_perm->$after_perm \033[0m"
	{
		echo "[U-63] /etc/sudoers: 소유자·권한 조치 완료"
		echo "  변경 전: 소유자=$before_owner, 권한=$before_perm"
		echo "  변경 후: 소유자=$after_owner, 권한=$after_perm"
	} >> "$CHANGE"
else
	echo -e "\033[0;32m[U-63] /etc/sudoers 소유자·권한 양호 (소유자=$owner, 권한=$perm) Good!! \033[0m"
	echo "[U-63] /etc/sudoers: 소유자·권한 양호 (소유자=$owner, 권한=$perm) - Good" >> "$GOOD"
fi

echo "========== [U-63] end =========="
