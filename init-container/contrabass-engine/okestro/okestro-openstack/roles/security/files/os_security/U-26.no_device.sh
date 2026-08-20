# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

not_device_list=$(find /dev -type f -exec ls -l {} \; 2>/dev/null | awk '{print $NF}')

if [[ "$not_device_list" == "" ]]; then
    echo "[U-26] /dev 내 일반 파일 없음 - Good" >> "$GOOD"
    echo -e "\033[0;32m[U-26] /dev regular file check Good!!\033[0m"
else
    echo -e "\033[0;31m[U-26] /dev 내 일반 파일 발견\033[0m"
    {
        echo "[U-26] /dev 내 일반 파일 발견"
        echo "  사유: /dev 디렉터리 내에 device 파일이 아닌 일반 파일이 존재합니다."
        echo "  조치 필요: 담당자가 직접 확인 후 불필요한 파일을 제거해 주세요."
        echo "  제거 명령: rm <파일 경로>"
        for i in $not_device_list; do echo "  - $i"; done
    } >> "$BAD"
fi
