# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
file=2-9.sticky_check_list.txt

while read line
do
    if [[ -e $line ]]; then
        file_location=$(ls -alL $line | awk '{print $NF}')
        check=$(ls -laL $file_location | awk '{print $1}' | grep -i 's')
        if [[ "$check" == "" ]]; then
            echo "[U-23] $file_location SUID/SGID 미설정 양호 - Good" >> "$GOOD"
            echo -e "\033[0;32m$file_location Not use Sticky bit Good!!\033[0m"
        else
            echo -e "\033[0;31m$file_location SUID/SGID 설정 발견 - 제거 조치\033[0m"
            chmod -s $file_location
            echo "[U-23] $file_location SUID/SGID 제거" >> "$CHANGE"
            echo "[U-23] $file_location SUID/SGID 제거 완료 - Good" >> "$GOOD"
        fi
    else
        echo "[U-23] $(echo $line) 파일 없음 - Good" >> "$GOOD"
        echo -e "\033[0;32m$(echo $line) not exist Good!!\033[0m"
    fi
done < 2-9.sticky_check_list.txt
