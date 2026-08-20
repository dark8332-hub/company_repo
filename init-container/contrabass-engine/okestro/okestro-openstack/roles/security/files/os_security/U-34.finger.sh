# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

if [ ! -e /etc/xinetd.d/finger ]; then
    echo "[U-34] Finger 서비스 없음 - Good" >> "$GOOD"
    echo -e "\033[0;32mFinger not exist Good!!\033[0m"
else
    ls -laL /etc/xinetd.d/finger 2>/dev/null | awk '{print $NF}' | while read line
    do
        service_check=$(cat $line | grep 'disable' | awk '{print $NF}')
        for i in $service_check
        do
            service_list=$(echo $line | awk -F/ '{print $NF}')
            if [[ "$i" == "yes" ]]; then
                echo "[U-34] $service_list Finger 비활성화 양호 - Good" >> "$GOOD"
                echo -e "\033[0;32m$service_list not use Good!!\033[0m"
            else
                echo -e "\033[0;31m$service_list Finger 활성화 발견 - 비활성화 조치\033[0m"
                sed -i "/disable/ s/$i/yes/g" $line
                systemctl restart xinetd 2>/dev/null
                echo "[U-34] $service_list Finger disable=yes 변경" >> "$CHANGE"
                echo "[U-34] $service_list Finger 비활성화 완료 - Good" >> "$GOOD"
            fi
        done
    done
fi
