# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi
for file in /etc/crontab /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly /var/spool/cron /etc/cron.d /etc/cron.yearly
do
        if [[ ! -e "$file" ]];
        then
                echo "[U-37] $file 없음 - Good" >> "$GOOD"
                echo -e "\033[0;32m$file File Not Exist GOOD!! \033[0m"
                continue
        fi

        echo -e "\033[0;32m$file Exist \033[0m"

        if [[ -f "$file" ]];
        then
                permission=$(stat -c '%a' "$file")

                if [[ "$permission" -le 640 ]];
                then
                        echo "[U-37] $file 권한 양호 - Good" >> "$GOOD"
                        echo -e "\033[0;32m$file Permission GOOD!! \033[0m"
                else
                        chmod 640 "$file"
                        echo "[U-37] $file 권한 이상 - 640으로 변경 완료" >> "$GOOD"
                        echo -e "\033[0;31m$file Permission BAD!! Change to 640 \033[0m"
                        echo "[U-37] $file 권한 640으로 변경" >> "$CHANGE"
                fi

        elif [[ -d "$file" ]];
        then
                permission=$(stat -c '%a' "$file")

                if [[ "$permission" -le 750 ]];
                then
                        echo "[U-37] $file 디렉터리 권한 양호 - Good" >> "$GOOD"
                        echo -e "\033[0;32m$file Directory Permission GOOD!! \033[0m"
                else
                        chmod 750 "$file"
                        echo "[U-37] $file 디렉터리 권한 이상 - 750으로 변경 완료" >> "$GOOD"
                        echo -e "\033[0;31m$file Directory Permission BAD!! Change to 750 \033[0m"
                        echo "[U-37] $file 디렉터리 권한 750으로 변경" >> "$CHANGE"
                fi
        fi

        file_owner=$(stat -c '%U' "$file")

        if [[ "$file_owner" == "root" ]];
        then
                echo "[U-37] $file 소유자 양호 - Good" >> "$GOOD"
                echo -e "\033[0;32m$file Owner GOOD!! \033[0m"
        else
                chown root "$file"
                echo "[U-37] $file 소유자 이상 - root로 변경 완료" >> "$GOOD"
                echo -e "\033[0;31m$file Owner BAD!! Change to root \033[0m"
                echo "[U-37] $file 소유자 root로 변경" >> "$CHANGE"
        fi
done
