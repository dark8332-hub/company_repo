# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

rservice=$(ls -alL /etc/xinetd.d/* 2>/dev/null | egrep "echo|daytime|discard|chargen" | grep -v "grep|klogin|kshell|kexec")

if [[ "$rservice" == "" ]]; then
    echo "[U-38] echo/daytime/discard/chargen 서비스 없음 - Good" >> "$GOOD"
    echo -e "\033[0;32mNot Exist DoS 취약 서비스 Good!!\033[0m"
else
    echo "$rservice" | while read line
    do
        rservice_name=$(echo $line | awk '{print $NF}')
        used_check=$(cat $rservice_name | grep 'disable' | awk '{print $3}')
        if [[ "$used_check" == "yes" ]]; then
            echo "[U-38] $rservice_name 비활성화 양호 - Good" >> "$GOOD"
            echo -e "\033[0;32m$rservice_name disabled Good!!\033[0m"
        elif [[ "$used_check" == "" ]]; then
            none_file=$(cat $rservice_name)
            if [[ "$none_file" == "" ]]; then
                echo "[U-38] $rservice_name 빈 파일 - Good" >> "$GOOD"
            else
                echo "[U-38] $rservice_name 파일 내용 확인 필요" >> "$CHANGE"
            fi
        else
            echo -e "\033[0;31m$rservice_name 활성화 발견 - 비활성화 조치\033[0m"
            sed -i "/disable/ s/= .*$/= yes/g" $rservice_name
            systemctl restart xinetd 2>/dev/null
            echo "[U-38] $rservice_name disable=yes 변경" >> "$CHANGE"
            echo "[U-38] $rservice_name DoS 서비스 비활성화 완료 - Good" >> "$GOOD"
        fi
    done
fi
