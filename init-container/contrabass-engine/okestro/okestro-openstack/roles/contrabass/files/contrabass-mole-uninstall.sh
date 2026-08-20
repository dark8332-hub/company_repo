#!/bin/sh

# 설정 변수
SERVICE_NAME="contrabass-mole.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
INSTALL_DIR="/var/lib/contrabass/mole"
LOG_DIR="/var/log/contrabass/mole"
CONFIG_DIR="/etc/contrabass/mole"

echo "----------------------------------------------------------------------------------------"
echo "Uninstalling Contrabass Mole"
echo "----------------------------------------------------------------------------------------"

# 서비스 중지
echo "Stopping $SERVICE_NAME"
systemctl stop "$SERVICE_NAME"

# 서비스 비활성화
echo "Disabling $SERVICE_NAME"
systemctl disable "$SERVICE_NAME"

# 서비스 파일 제거
echo "Removing $SERVICE_FILE"
if [ -f "$SERVICE_FILE" ]; then
    rm "$SERVICE_FILE"
fi

# systemd 데몬 리로드
echo "Reloading systemd daemon"
systemctl daemon-reload

# 실패한 서비스 상태 초기화
echo "Resetting failed state for $SERVICE_NAME"
systemctl reset-failed "$SERVICE_NAME"

# 설치 디렉토리 제거
echo "Removing $INSTALL_DIR"
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
fi

# 로그 디렉토리 제거
echo "Removing $LOG_DIR"
if [ -d "$LOG_DIR" ]; then
    rm -rf "$LOG_DIR"
fi

# 설정 디렉토리 제거
echo "Removing $CONFIG_DIR"
if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
fi

echo "Uninstallation complete"