#!/bin/bash
# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

LOGIN_DEFS="/etc/login.defs"
COMMON_PW="/etc/pam.d/common-password"

echo "========== [U-13] 패스워드 암호화 알고리즘 점검 =========="

# Step 1: /etc/login.defs ENCRYPT_METHOD 확인 및 조치
echo "--- Step1: /etc/login.defs ENCRYPT_METHOD 확인 ---"
cur_method=$(grep -iE '^[[:space:]]*ENCRYPT_METHOD[[:space:]]' "$LOGIN_DEFS" 2>/dev/null | grep -v '^#' | awk '{print toupper($2)}' | head -1)

if echo "SHA256 SHA512 YESCRYPT" | grep -qw "$cur_method"; then
    echo -e "\033[0;32m[U-13] ENCRYPT_METHOD $cur_method Good!!\033[0m"
    echo "[U-13] ENCRYPT_METHOD: $cur_method - Good" >> "$GOOD"
else
    echo -e "\033[0;31m[U-13] ENCRYPT_METHOD '$cur_method' 취약 → SHA512 으로 변경\033[0m"
    if grep -qiE '^[[:space:]]*ENCRYPT_METHOD[[:space:]]' "$LOGIN_DEFS"; then
        sed -i 's/^[[:space:]]*ENCRYPT_METHOD[[:space:]].*/ENCRYPT_METHOD SHA512/' "$LOGIN_DEFS"
    else
        echo "ENCRYPT_METHOD SHA512" >> "$LOGIN_DEFS"
    fi
    {
        echo "[U-13] ENCRYPT_METHOD: '$cur_method' → SHA512 변경"
        echo "  파일: $LOGIN_DEFS"
    } >> "$CHANGE"
    echo "[U-13] ENCRYPT_METHOD SHA512 변경 완료 - Good" >> "$GOOD"
fi

# Step 2: /etc/pam.d/common-password pam_unix.so 알고리즘 확인 및 조치
echo "--- Step2: /etc/pam.d/common-password pam_unix.so 알고리즘 확인 ---"
if [[ ! -f "$COMMON_PW" ]]; then
    echo -e "\033[0;31m[U-13] $COMMON_PW 파일 없음\033[0m"
    {
        echo "[U-13] $COMMON_PW: 파일 없음"
        echo "  사유: common-password 파일이 없어 알고리즘 확인 불가합니다."
        echo "  조치 필요: 파일을 직접 확인해 주세요."
    } >> "$BAD"
else
    pam_unix_line=$(grep -iE 'pam_unix\.so' "$COMMON_PW" | grep -v '^[[:space:]]*#' | head -1)
    pam_algo=""
    for algo in sha256 sha512 yescrypt; do
        if echo "$pam_unix_line" | grep -qi "$algo"; then
            pam_algo="$algo"
            break
        fi
    done

    if [[ -n "$pam_algo" ]]; then
        echo -e "\033[0;32m[U-13] pam_unix.so 알고리즘: $pam_algo Good!!\033[0m"
        echo "[U-13] pam_unix.so 알고리즘: $pam_algo - Good" >> "$GOOD"
    else
        echo -e "\033[0;31m[U-13] pam_unix.so SHA-2 이상 알고리즘 미설정 → yescrypt 추가\033[0m"
        sed -i '/pam_unix\.so/ s/$/ yescrypt/' "$COMMON_PW"
        {
            echo "[U-13] pam_unix.so: SHA-2 이상 알고리즘 미설정 → yescrypt 추가"
            echo "  파일: $COMMON_PW"
        } >> "$CHANGE"
        echo "[U-13] pam_unix.so yescrypt 추가 완료 - Good" >> "$GOOD"
    fi
fi

echo "========== [U-13] end =========="
