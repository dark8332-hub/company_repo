# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

# PDF U-29: /etc/hosts.lpd 파일 소유자 및 권한 설정
# 양호: 파일 없거나, 있으면 소유자 root + 권한 600 이하

file="/etc/hosts.lpd"

if [[ ! -e "$file" ]]; then
    echo "[U-29] $file 파일 없음 - Good" >> "$GOOD"
    echo -e "\033[0;32m[U-29] $file not exists - Good!!\033[0m"
    exit 0
fi

perm_octal=$(stat -c "%a" "$file")
owner=$(stat -c "%U" "$file")
issues=""

if [[ "$owner" != "root" ]]; then
    issues="${issues} 소유자(${owner}!=root)"
    chown root "$file"
    echo "[U-29] $file 소유자 root로 변경" >> "$CHANGE"
fi

if [[ "$perm_octal" -gt "600" ]]; then
    issues="${issues} 권한(${perm_octal}>600)"
    chmod 600 "$file"
    echo "[U-29] $file 권한 600으로 변경" >> "$CHANGE"
fi

if [[ -z "$issues" ]]; then
    echo "[U-29] $file 소유자 및 권한 양호 (owner=root, perm=${perm_octal}) - Good" >> "$GOOD"
    echo -e "\033[0;32m[U-29] $file Good!!\033[0m"
else
    echo "[U-29] $file 이상 감지: ${issues} - 자동 조치 완료" >> "$GOOD"
    echo -e "\033[0;31m[U-29] $file 이상: ${issues} - 조치 완료\033[0m"
fi
