#!/bin/sh


echo "----------------------------------------------------------------------------------------"
echo "Installing Contrabass Mole"
echo "----------------------------------------------------------------------------------------"

# 입력 인자 확인
if [ "$1" != "control" ] && [ "$1" != "compute" ]; then
    echo "오류: 지원하지 않는 값입니다. [control|compute] 중 하나를 입력하세요."
    exit 1
fi

ROLE=$1

# 설정 변수
TAR_FILE="contrabass-mole.tar.gz"
TEMP_DIR="/tmp/contrabass-mole"
INSTALL_DIR="/var/lib/contrabass/mole"
LOG_DIR="/var/log/contrabass/mole"
CONFIG_DIR="/etc/contrabass/mole"
SERVICE_FILE="/etc/systemd/system/contrabass-mole.service"
SERVICE_NAME="contrabass-mole.service"

# 압축 파일을 /tmp에 풀기
echo "Extracting $TAR_FILE to $TEMP_DIR"
mkdir -p "$TEMP_DIR"
tar -xzf "$TAR_FILE" -C "$TEMP_DIR"

if [ $? -eq 0 ]; then
    echo "압축 해제 성공"
else
    echo "압축 해제 실패"
    exit 1
fi

# /var/lib/contrabass/mole 디렉토리 생성
echo "Creating $INSTALL_DIR if it doesn't exist"
mkdir -p "$INSTALL_DIR"

# 필요한 파일을 /var/lib/contrabass/mole로 복사
echo "Copying files to $INSTALL_DIR"
cp "$TEMP_DIR/startB.sh" "$INSTALL_DIR"
cp "$TEMP_DIR/start.sh" "$INSTALL_DIR"
cp "$TEMP_DIR/status.sh" "$INSTALL_DIR"
cp "$TEMP_DIR/stop.sh" "$INSTALL_DIR"
cp "$TEMP_DIR/test-control-api.sh" "$INSTALL_DIR"
cp "$TEMP_DIR/test-compute-api.sh" "$INSTALL_DIR"

# ROLE에 따라 실행 파일 복사
if [ "$ROLE" = "control" ]; then
    echo "Copying contrabass-moleU-control to $INSTALL_DIR/contrabass-moleU"
    cp "$TEMP_DIR/contrabass-moleU-control" "$INSTALL_DIR/contrabass-moleU"
else
    echo "Copying contrabass-moleU-compute to $INSTALL_DIR/contrabass-moleU"
    cp "$TEMP_DIR/contrabass-moleU-compute" "$INSTALL_DIR/contrabass-moleU"
fi

# 파일에 실행 권한 추가
chmod +x "$INSTALL_DIR/startB.sh"
chmod +x "$INSTALL_DIR/start.sh"
chmod +x "$INSTALL_DIR/status.sh"
chmod +x "$INSTALL_DIR/stop.sh"
chmod +x "$INSTALL_DIR/test-control-api.sh"
chmod +x "$INSTALL_DIR/test-compute-api.sh"
chmod +x "$INSTALL_DIR/contrabass-moleU"

# /var/log/contrabass 디렉토리 생성
echo "Creating $LOG_DIR if it doesn't exist"
mkdir -p "$LOG_DIR"

# /etc/contrabass/mole 디렉토리 생성
echo "Creating $CONFIG_DIR if it doesn't exist"
mkdir -p "$CONFIG_DIR"

# agent.local.yml 파일을 /etc/contrabass/mole로 복사
echo "Copying configuration files to $CONFIG_DIR"
cp "$TEMP_DIR/agent.local.yml" "$CONFIG_DIR"
cp "$TEMP_DIR/node-backup-db-backup.sh" "$CONFIG_DIR"
cp "$TEMP_DIR/node-backup-db-remove.sh" "$CONFIG_DIR"
cp "$TEMP_DIR/node-backup-env-test.sh" "$CONFIG_DIR"
cp "$TEMP_DIR/node-backup-config-backup.sh" "$CONFIG_DIR"
cp "$TEMP_DIR/config-backup-list.cfg" "$CONFIG_DIR"
cp "$TEMP_DIR/config-backup-list.cfg.bak" "$CONFIG_DIR"

chmod +x "$CONFIG_DIR/node-backup-db-backup.sh"
chmod +x "$CONFIG_DIR/node-backup-db-remove.sh"
chmod +x "$CONFIG_DIR/node-backup-env-test.sh"
chmod +x "$CONFIG_DIR/node-backup-config-backup.sh"

# 서비스 유닛 파일 작성
echo "Creating systemd service file at $SERVICE_FILE"
cat <<EOL > "$SERVICE_FILE"
[Unit]
Description=Contrabass Mole Service
After=network.target

[Service]
Environment='LANG=C'
ExecStart=/var/lib/contrabass/mole/contrabass-moleU -cfg /etc/contrabass/mole/agent.local.yml
ExecStop=/var/lib/contrabass/mole/stop.sh

# 프로그램이 비정상적으로 종료되어도 다시 구동을 시켜준다. 예) kill 로 죽인 경우
Restart=on-failure
User=root
Group=root

# simple 로 하게 되면 startB.sh 로 실행하지 않고 직접 실행해도 백그라운드로 작동을 하게 된다.
Type=simple

[Install]
WantedBy=multi-user.target
EOL

# 권한 설정
chmod 644 "$SERVICE_FILE"

# systemd 데몬 리로드
echo "Reloading systemd daemon"
systemctl daemon-reload

# 서비스 시작 및 부팅 시 자동 시작 설정
echo "Starting and enabling $SERVICE_NAME"
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

echo "Installation complete"