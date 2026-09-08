#!/bin/sh
# OpenStack 운영 지원 플랫폼 - 운영 명령
# 사용법: ./opsctl.sh {start|stop|restart|status|logs|shell|backup|restore|remove}

set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
    cat <<'EOF'

사용법: ./opsctl.sh <명령>

  status            컨테이너 상태와 응답 확인
  start             기동
  stop              정지 (데이터는 남습니다)
  restart           재기동. config.env 를 고친 뒤 이 명령으로 반영합니다
  logs [줄수]       최근 로그 (기본 100줄). `logs -f` 로 실시간 확인
  shell             컨테이너 안 셸

  backup [경로]     data 디렉터리를 tar.gz 로 묶습니다 (공급자 DB + 마스터 키)
  restore <파일>    백업 파일로 되돌립니다

  remove            컨테이너와 이미지를 지웁니다. data 디렉터리는 남깁니다
  remove --all      data 디렉터리까지 지웁니다 (되돌릴 수 없습니다)

EOF
}

[ $# -ge 1 ] || { usage; exit 1; }
COMMAND="$1"; shift

case "$COMMAND" in
    -h|--help|help) usage; exit 0 ;;
esac

detect_runtime
load_config

case "$COMMAND" in

status)
    log ""
    log "런타임      $RUNTIME${RUNTIME_ARGS:+ $RUNTIME_ARGS}"
    log "컨테이너    $CONTAINER_NAME"
    if container_exists; then
        rt ps -a --filter "name=$CONTAINER_NAME" --format '상태        {{.Status}}'
    else
        log "상태        없음 (install.sh 를 실행하세요)"
        exit 1
    fi
    log "데이터      $DATA_DIR"
    if [ -f "$DATA_DIR/providers.db" ]; then
        log "            providers.db $(du -h "$DATA_DIR/providers.db" | awk '{print $1}')"
    else
        log "            아직 없음 (공급자 등록 전)"
    fi
    if [ -f "$DATA_DIR/.master_key" ]; then
        log "            마스터 키 있음 - 백업 대상입니다"
    else
        log "            마스터 키 없음 (첫 공급자 등록 시 생성)"
    fi
    log "주소        $(server_url)"
    printf '응답        '
    if container_running && wait_healthy 5; then
        log "정상"
    else
        log "없음 - ./opsctl.sh logs 로 원인을 확인하세요"
        exit 1
    fi
    log ""
    ;;

start)
    container_running && { info "이미 실행 중입니다."; exit 0; }
    if container_exists; then rt start "$CONTAINER_NAME" >/dev/null; else start_container; fi
    wait_healthy && ok "기동 완료: $(server_url)" || die "기동했지만 응답이 없습니다. ./opsctl.sh logs 를 확인하세요."
    ;;

stop)
    container_exists || die "컨테이너가 없습니다."
    rt stop "$CONTAINER_NAME" >/dev/null
    ok "정지했습니다. 데이터는 $DATA_DIR 에 그대로 있습니다."
    ;;

restart)
    # config.env 를 고쳤을 수 있으므로 start/stop 이 아니라 컨테이너를 다시 만든다.
    # 환경 변수와 포트는 생성 시점에 고정되기 때문이다.
    container_exists && rt rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    start_container
    wait_healthy && ok "재기동 완료: $(server_url)" || die "재기동했지만 응답이 없습니다. ./opsctl.sh logs 를 확인하세요."
    ;;

logs)
    container_exists || die "컨테이너가 없습니다."
    case "${1:-}" in
        -f|--follow) rt logs --follow "$CONTAINER_NAME" ;;
        "")          rt logs --tail 100 "$CONTAINER_NAME" ;;
        *)           rt logs --tail "$1" "$CONTAINER_NAME" ;;
    esac
    ;;

shell)
    container_running || die "컨테이너가 실행 중이 아닙니다."
    rt exec -it "$CONTAINER_NAME" /bin/sh
    ;;

backup)
    [ -d "$DATA_DIR" ] || die "데이터 디렉터리가 없습니다."
    target="${1:-$BUNDLE_DIR/backup/$APP_NAME-data-$(date +%Y%m%d-%H%M%S).tar.gz}"
    mkdir -p "$(dirname "$target")"
    # SQLite 가 쓰는 중에 복사하면 깨질 수 있어 잠시 멈춘다.
    was_running=no
    if container_running; then was_running=yes; rt stop "$CONTAINER_NAME" >/dev/null; info "일관성을 위해 잠시 정지"; fi
    tar -czf "$target" -C "$BUNDLE_DIR" data
    chmod 600 "$target"
    [ "$was_running" = yes ] && rt start "$CONTAINER_NAME" >/dev/null && info "재기동"
    ok "백업: $target ($(du -h "$target" | awk '{print $1}'))"
    warn "이 파일에는 SSH·MySQL 비밀번호를 푸는 마스터 키가 들어 있습니다. 접근 통제된 곳에 보관하세요."
    ;;

restore)
    [ $# -ge 1 ] || die "복원할 파일을 지정하세요: ./opsctl.sh restore <파일>"
    archive="$1"
    [ -f "$archive" ] || die "파일이 없습니다: $archive"
    tar -tzf "$archive" | grep -q '^data/' || die "이 파일에는 data/ 가 없습니다. 백업 파일이 맞는지 확인하세요."
    container_exists && rt rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    if [ -d "$DATA_DIR" ]; then
        keep="$DATA_DIR.before-restore-$(date +%Y%m%d-%H%M%S)"
        mv "$DATA_DIR" "$keep"
        info "기존 데이터를 $keep 로 옮겼습니다."
    fi
    tar -xzf "$archive" -C "$BUNDLE_DIR"
    start_container
    wait_healthy && ok "복원 후 기동 완료: $(server_url)" || die "복원했지만 응답이 없습니다. ./opsctl.sh logs 를 확인하세요."
    ;;

remove)
    container_exists && rt rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    ok "컨테이너 제거"
    rt rmi "$IMAGE_REPO:$IMAGE_TAG" >/dev/null 2>&1 && ok "이미지 제거" || info "이미지는 없거나 다른 곳에서 쓰고 있습니다."
    if [ "${1:-}" = "--all" ]; then
        rm -rf "$DATA_DIR"
        ok "데이터 삭제"
        log ""
        log "  이 디렉터리를 지우면 흔적이 남지 않습니다: rm -rf $BUNDLE_DIR"
    else
        log ""
        info "데이터는 남겨 두었습니다: $DATA_DIR"
        info "완전히 지우려면 ./opsctl.sh remove --all"
    fi
    ;;

*)
    warn "알 수 없는 명령: $COMMAND"
    usage
    exit 1
    ;;
esac
