# 부모 스크립트(os_script_start.sh)에서 export된 변수 우선 사용
if [[ -z "$GOOD" ]]; then
    TS=$(date +%y%m%d%H%M%S)
    GOOD="./good_list_${TS}.txt"
    BAD="./bad_list_${TS}.txt"
    CHANGE="./change_list.txt"
fi

ftp_user=$(grep ^ftp /etc/passwd)

if [[ "$ftp_user" == *"ftp"* ]]; then
    echo -e "\033[0;31mFTP 계정 발견 - 삭제 조치\033[0m"
    deluser ftp 2>/dev/null
    echo "[U-35] ftp 계정 삭제 (deluser ftp)" >> "$CHANGE"
    echo "[U-35] ftp 계정 삭제 완료 - Good" >> "$GOOD"
else
    echo "[U-35] FTP 익명 계정 없음 - Good" >> "$GOOD"
    echo -e "\033[0;32mFTP User Not Exist Good!!\033[0m"
fi

vsftp_check=$(dpkg -l 2>/dev/null | grep vsftpd)

if [[ "$vsftp_check" == "" ]]; then
    echo "[U-35] vsftpd 미설치 - Good" >> "$GOOD"
    echo -e "\033[0;32mvsftpd Not Installed Good!!\033[0m"
else
    if [ ! -e /etc/vsftpd.conf ]; then
        echo "[U-35] vsftpd.conf 없음 - Good" >> "$GOOD"
        echo -e "\033[0;32mvsftpd.conf Not Exist Good!!\033[0m"
    else
        anonymous_enable=$(grep anonymous_enable /etc/vsftpd.conf | awk -F= '{print $2}')
        if [[ "${anonymous_enable^^}" == "NO" ]]; then
            echo "[U-35] FTP 익명 접속 비활성화 양호 - Good" >> "$GOOD"
            echo -e "\033[0;32mFTP Anonymous Disabled Good!!\033[0m"
        else
            echo -e "\033[0;31mFTP 익명 접속 활성화 발견 - 비활성화 조치\033[0m"
            sed -i "s/anonymous_enable=${anonymous_enable}/anonymous_enable=NO/g" /etc/vsftpd.conf
            echo "[U-35] vsftpd.conf anonymous_enable=NO 변경" >> "$CHANGE"
            echo "[U-35] FTP 익명 접속 비활성화 완료 - Good" >> "$GOOD"
        fi
    fi
fi
