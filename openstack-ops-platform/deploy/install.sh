#!/bin/sh
# OpenStack 운영 지원 플랫폼 - 폐쇄망 설치
#
# 이 스크립트는 번들 디렉터리 밖에 아무것도 쓰지 않는다. 패키지를 설치하지 않고,
# 시스템 설정을 고치지 않으며, 남기는 것은 컨테이너 하나와 이 디렉터리 아래의 data/ 뿐이다.
# 되돌리려면 ./opsctl.sh remove 를 실행하고 디렉터리를 지우면 된다.

set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

log ""
log "OpenStack 운영 지원 플랫폼 설치"
log "=============================================="

# --- 1. 실행 환경 -----------------------------------------------------------
log ""
log "[1/6] 실행 환경 확인"

arch="$(uname -m)"
case "$arch" in
    x86_64|amd64) ok "아키텍처 $arch" ;;
    *) die "이 이미지는 x86_64 전용입니다. 이 서버는 $arch 입니다.
  대상 아키텍처에서 다시 빌드해야 합니다." ;;
esac

detect_runtime
ok "컨테이너 런타임 $RUNTIME${RUNTIME_ARGS:+ ($RUNTIME_ARGS)}"

if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
    info "SELinux enforcing - 바인드 마운트에 :Z 를 자동으로 붙입니다."
fi

# --- 2. 설정 ---------------------------------------------------------------
log ""
log "[2/6] 설정 파일"

if [ ! -f "$CONFIG_FILE" ]; then
    cp "$BUNDLE_DIR/config.env.example" "$CONFIG_FILE"
    ok "config.env 생성 (config.env.example 복사)"
else
    ok "config.env 가 이미 있어 그대로 씁니다."
fi
load_config
info "포트 $HOST_PORT, 시간대 ${TIMEZONE:-Asia/Seoul}, 컨테이너 이름 $CONTAINER_NAME"

# host 네트워크에서는 HOST_PORT 가 무시되고 컨테이너가 8090 을 그대로 잡으므로 실제 포트로 검사한다.
# 우리 컨테이너가 이미 그 포트를 쓰고 있는 재설치도 있으므로, 여기서는 알리기만 하고
# 판정은 기존 컨테이너를 내린 뒤 [5/6] 에서 한다.
check_port="$(effective_port)"
if port_in_use "$check_port" && ! container_running; then
    die "$check_port 포트를 이미 다른 프로세스가 쓰고 있습니다.
  이 서버에서 돌고 있는 서비스를 건드리지 않도록 설치를 중단합니다.
  config.env 의 HOST_PORT 를 비어 있는 포트로 바꾸고 다시 실행하세요.$(
    [ "${USE_HOST_NETWORK:-no}" = "yes" ] && printf '\n  USE_HOST_NETWORK=yes 에서는 HOST_PORT 가 무시되고 8090 을 씁니다.'
  )"
fi

# --- 3. 이미지 적재 ---------------------------------------------------------
log ""
log "[3/6] 이미지 적재"

archive="$BUNDLE_DIR/image/$APP_NAME-$IMAGE_TAG.tar"
[ -f "$archive" ] || die "이미지 파일이 없습니다: $archive
  번들이 온전히 풀렸는지 확인하세요."

if [ -f "$BUNDLE_DIR/image/SHA256SUMS" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
        ( cd "$BUNDLE_DIR/image" && sha256sum -c SHA256SUMS >/dev/null 2>&1 ) \
            && ok "이미지 무결성 확인" \
            || die "이미지 체크섬이 맞지 않습니다. 전송 중 파일이 손상됐습니다. 다시 반입하세요."
    else
        warn "sha256sum 이 없어 무결성 검증을 건너뜁니다."
    fi
fi

info "적재 중... (약 87MB, 30초 내외)"
rt load --input "$archive" >/dev/null || die "이미지 적재 실패."
rt image inspect "$IMAGE_REPO:$IMAGE_TAG" >/dev/null 2>&1 \
    || die "적재 후에도 $IMAGE_REPO:$IMAGE_TAG 이미지가 보이지 않습니다."
ok "$IMAGE_REPO:$IMAGE_TAG"

# --- 4. 데이터 디렉터리 -----------------------------------------------------
log ""
log "[4/6] 데이터 디렉터리"

mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"
if [ -f "$DATA_DIR/providers.db" ]; then
    ok "기존 데이터를 그대로 씁니다: $DATA_DIR"
    info "공급자·점검 이력·알림이 보존됩니다."
else
    ok "새 데이터 디렉터리: $DATA_DIR"
    info "공급자는 등록된 것이 없습니다. 접속 후 [공급자 연결]에서 새로 등록하세요."
fi

# --- 5. 기동 ---------------------------------------------------------------
log ""
log "[5/6] 컨테이너 기동"

prepare_replacement

start_container
ok "컨테이너 시작: $CONTAINER_NAME"

# --- 6. 확인 ---------------------------------------------------------------
log ""
log "[6/6] 동작 확인"

if wait_healthy; then
    ok "/api/health 응답 정상"
else
    log ""
    warn "60초 안에 응답하지 않았습니다. 로그를 확인하세요:"
    log ""
    rt logs --tail 30 "$CONTAINER_NAME" 2>&1 | sed 's/^/    /'
    # 재시작 루프를 남기지 않는다. 원인을 고친 뒤 ./install.sh 를 다시 실행하면 된다.
    stop_failed_container
    die "기동 실패. 컨테이너는 정지시켰습니다(재시작 루프 방지).
  원인을 고친 뒤 ./install.sh 를 다시 실행하세요."
fi

log ""
log "=============================================="
log "설치 완료"
log ""
log "  접속 주소   $(server_url)"
log "  계정        ${ADMIN_USERNAME:-admin}"
if [ -n "${ADMIN_PASSWORD:-}" ]; then
    log "  비밀번호    config.env 의 ADMIN_PASSWORD 값"
else
    log "  비밀번호    Okestro2018@   (첫 로그인에서 반드시 변경합니다)"
fi
log ""
log "  다음 순서로 진행하세요."
log "    1. 위 주소로 접속해 로그인하고 비밀번호를 변경합니다."
log "    2. [공급자 연결]에서 대표 VIP·SSH 계정으로 공급자를 등록합니다."
log "    3. [일일점검]에서 클러스터 노드를 탐색한 뒤 점검을 실행합니다."
log ""
log "  운영 명령    ./opsctl.sh {status|logs|restart|stop|backup|remove}"
log "  설정 변경    config.env 수정 후 ./opsctl.sh restart"
if [ "$RUNTIME_KIND" != "docker" ]; then
    # docker 만 --restart unless-stopped 로 재부팅 후 자동 기동한다. podman·nerdctl 은 유닛이 필요하다.
    log "  자동 기동    sudo ./opsctl.sh install-service   ($RUNTIME 은 재부팅 후 자동 기동되지 않습니다)"
fi
log ""
if [ -n "${ADMIN_PASSWORD:-}" ]; then
    warn "config.env 에 초기 비밀번호가 평문으로 남아 있습니다."
    warn "로그인 후 config.env 의 ADMIN_PASSWORD 를 비우고 ./opsctl.sh restart 하세요."
    log ""
fi
