#!/bin/bash
# 부모 스크립트(controller_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# [2] Apache LimitRequestBody 설정 점검 및 조치
# <Directory /> 블록에 LimitRequestBody 5000000 이상 설정 여부 확인
# 없으면 추가, 5000000 미만이면 5000000 으로 변경

APACHE_CONF="/etc/apache2/apache2.conf"
LIMIT_MIN=5000000

echo "========== [2] Apache LimitRequestBody check =========="

# Apache 프로세스 확인
apache_check=$(ps -ef | grep apache2 | grep -v grep)
if [[ -z "$apache_check" ]]; then
	echo -e "\033[0;32m[2] Apache Not use \033[0m"
	echo "[2] Apache: 미사용 - Good" >> "$GOOD"
	echo "========== [2] end =========="
	exit 0
fi

# <Directory /> 블록 안의 LimitRequestBody 값 추출
limit_val=$(awk '
	/^[[:space:]]*<Directory[[:space:]]+"?\/"?>/ { in_root=1 }
	in_root && /^[[:space:]]*<\/Directory>/ { in_root=0 }
	in_root && /^[[:space:]]*LimitRequestBody/ && !/^[[:space:]]*#/ { print $2 }
' "$APACHE_CONF")

if [[ -z "$limit_val" ]]; then
	echo -e "\033[0;31m[2] LimitRequestBody 없음 → 추가 조치 \033[0m"

	python3 - "$APACHE_CONF" "$LIMIT_MIN" << 'PYEOF'
import sys, re
path = sys.argv[1]
limit = sys.argv[2]
with open(path, 'r') as f:
    lines = f.readlines()
result = []
in_root = False
inserted = False
for line in lines:
    result.append(line)
    if re.match(r'\s*<Directory\s+"?/\"?>\s*$', line):
        in_root = True
    if in_root and not inserted and not re.match(r'\s*</Directory>', line) and line.strip() != '':
        if re.match(r'\s*<Directory', line):
            result.append(f'\tLimitRequestBody {limit}\n')
            inserted = True
    if in_root and re.match(r'\s*</Directory>', line):
        if not inserted:
            result.insert(-1, f'\tLimitRequestBody {limit}\n')
            inserted = True
        in_root = False
with open(path, 'w') as f:
    f.writelines(result)
PYEOF

	{
		echo "[2] Apache LimitRequestBody: 설정 없음 → 추가"
		echo "  파일: $APACHE_CONF"
		echo "  조치: <Directory /> 블록에 LimitRequestBody $LIMIT_MIN 추가"
	} >> "$CHANGE"
	systemctl restart apache2
	echo "  Apache2 재시작 완료" >> "$CHANGE"
	echo -e "\033[0;32m[2] LimitRequestBody $LIMIT_MIN 추가 및 Apache 재시작 완료 \033[0m"
	echo "[2] Apache LimitRequestBody: 설정 없음 → $LIMIT_MIN 추가 완료 - Good" >> "$GOOD"

elif [[ "$limit_val" -lt "$LIMIT_MIN" ]]; then
	echo -e "\033[0;31m[2] LimitRequestBody $limit_val < $LIMIT_MIN → 변경 조치 \033[0m"

	python3 - "$APACHE_CONF" "$limit_val" "$LIMIT_MIN" << 'PYEOF'
import sys, re
path = sys.argv[1]
old_val = sys.argv[2]
new_val = sys.argv[3]
with open(path, 'r') as f:
    lines = f.readlines()
result = []
in_root = False
for line in lines:
    if re.match(r'\s*<Directory\s+"?/\"?>\s*$', line):
        in_root = True
    if in_root and re.match(r'\s*</Directory>', line):
        in_root = False
    if in_root and re.match(r'\s*LimitRequestBody\s+', line) and not line.strip().startswith('#'):
        line = re.sub(r'(LimitRequestBody\s+)\d+', f'\\g<1>{new_val}', line)
    result.append(line)
with open(path, 'w') as f:
    f.writelines(result)
PYEOF

	{
		echo "[2] Apache LimitRequestBody: 값 변경"
		echo "  파일: $APACHE_CONF"
		echo "  변경: $limit_val → $LIMIT_MIN"
	} >> "$CHANGE"
	systemctl restart apache2
	echo "  Apache2 재시작 완료" >> "$CHANGE"
	echo -e "\033[0;32m[2] LimitRequestBody $limit_val → $LIMIT_MIN 변경 및 Apache 재시작 완료 \033[0m"
	echo "[2] Apache LimitRequestBody: $limit_val → $LIMIT_MIN 변경 완료 - Good" >> "$GOOD"

else
	echo -e "\033[0;32m[2] LimitRequestBody $limit_val Good!! \033[0m"
	echo "[2] Apache LimitRequestBody: $limit_val (≥$LIMIT_MIN) - Good" >> "$GOOD"
fi

echo "========== [2] end =========="
