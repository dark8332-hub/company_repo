#!/bin/bash
# 1-11: 시스템 관리자 그룹(root) 최소 계정 여부 점검 (조치 안 함, 판별만)
# /etc/group 에서 root 그룹에 포함된 계정 확인
# root 그룹 멤버가 없으면 Good, 있으면 bad_list + 직접 확인·제거하라는 멘트

# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

echo "========== [U-08] root group member check =========="

# root 그룹 라인에서 멤버 추출 (4번째 필드)
root_members=$(grep "^root:" /etc/group | cut -d: -f4)

if [[ -z "$root_members" ]]; then
	echo -e "\033[0;32m[U-08] root 그룹에 추가 계정 없음 Good!! \033[0m"
	echo "[U-08] root 그룹 멤버: 없음 - Good" >> "$GOOD"
else
	echo -e "\033[0;31m[U-08] root 그룹에 계정 존재: $root_members \033[0m"
	{
		echo "[U-08] root 그룹 멤버 존재"
		echo "  계정 목록: $root_members"
		echo "  사유: root 그룹에 불필요한 계정이 포함되어 있습니다."
		echo "  조치 필요: 시스템 관리에 불필요한 계정은 root 그룹에서 직접 제거해 주세요."
		echo "  제거 명령: gpasswd -d [계정명] root"
	} >> "$BAD"
fi

echo "========== [U-08] end =========="
