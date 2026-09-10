#!/bin/sh
# OpenStack 운영 지원 플랫폼 - 운영 명령
# 사용법: ./opsctl.sh {start|stop|restart|status|logs|shell|backup|restore|remove|install-service}

set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

# systemd 유닛을 놓는 자리. 환경 변수로 바꿀 수 있는 것은 회귀 테스트를 위한 것으로 보통은
# 건드리지 않는다(런타임 번들의 install-runtime.sh 와 같은 방식이다).
UNIT_DIR="${OPS_UNIT_DIR:-/etc/systemd/system}"
SERVICE_RECORD="$BUNDLE_DIR/installed-service.txt"
# 이 줄이 있는 유닛만 우리 것으로 본다. 같은 이름의 남의 유닛을 덮어쓰지 않기 위한 표식이다.
SERVICE_MARKER="# openstack-ops-platform bundle"

# 유닛 서식의 __BUNDLE_DIR__ 을 이 번들 경로로 바꾼다. sed 가 아니라 awk 의 index/substr 로
# 글자 그대로 바꾼다. 경로에 sed 구분자나 & 가 들어가도 안전하고, 무엇보다 운영자가 손으로
# sed 를 칠 때 자리표시자의 밑줄을 빠뜨려 `__/경로__` 가 박힌 유닛이 만들어지는 일을 없앤다.
# systemd 는 그런 유닛을 bad-setting 으로 거부하며, 그 원인은 로그를 봐야만 알 수 있다.
render_unit() {
    awk -v dir="$BUNDLE_DIR" '
        {
            line = $0; out = ""
            while ((i = index(line, "__BUNDLE_DIR__")) > 0) {
                out = out substr(line, 1, i - 1) dir
                line = substr(line, i + 14)
            }
            print out line
        }
    ' "$1"
}

usage() {
    cat <<'EOF'

사용법: ./opsctl.sh <명령>

  status            컨테이너 상태와 응답 확인
  start             기동
  stop              정지 (데이터는 남습니다)
  restart           재기동. config.env 를 고친 뒤 이 명령으로 반영합니다
  logs [줄수]       최근 로그 (기본 100줄). `logs -f` 로 실시간 확인
  shell             컨테이너 안 셸
  netcheck <호스트> [포트]
                    컨테이너에서 점검 대상 노드까지 닿는지 단계별로 확인합니다
                    (기본 포트 22). 점검이 SSH 단계에서 실패할 때 씁니다

  backup [경로]     data 디렉터리를 tar.gz 로 묶습니다 (공급자 DB + 마스터 키)
  restore <파일>    백업 파일로 되돌립니다

  remove            컨테이너와 이미지를 지웁니다. data 디렉터리는 남깁니다
  remove --all      data 디렉터리까지 지웁니다 (되돌릴 수 없습니다)

  install-service   재부팅 후 자동 기동되도록 systemd 유닛을 설치합니다 (root 필요).
                    번들 디렉터리 밖에 파일을 만드는 유일한 명령입니다
  uninstall-service 그 유닛을 제거합니다. 컨테이너는 그대로 둡니다 (root 필요)

EOF
}

[ $# -ge 1 ] || { usage; exit 1; }
COMMAND="$1"; shift

case "$COMMAND" in
    -h|--help|help) usage; exit 0 ;;
esac

detect_runtime
load_config
# All actions targeting a container share the same ownership check.
case "$COMMAND" in
    start|stop|restart|backup|restore|remove|logs|shell|netcheck|install-service) require_owned_container ;;
esac

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
    if container_exists; then require_free_port; rt start "$CONTAINER_NAME" >/dev/null; else start_container; fi
    wait_healthy && ok "기동 완료: $(server_url)" || { stop_failed_container; die "기동했지만 응답이 없습니다(컨테이너는 정지). ./opsctl.sh logs 를 확인하세요."; }
    ;;

stop)
    container_exists || die "컨테이너가 없습니다."
    rt stop "$CONTAINER_NAME" >/dev/null
    ok "정지했습니다. 데이터는 $DATA_DIR 에 그대로 있습니다."
    ;;

restart)
    # config.env 를 고쳤을 수 있으므로 start/stop 이 아니라 컨테이너를 다시 만든다.
    # 환경 변수와 포트는 생성 시점에 고정되기 때문이다.
    prepare_replacement
    start_container
    wait_healthy && ok "재기동 완료: $(server_url)" || { stop_failed_container; die "재기동했지만 응답이 없습니다(컨테이너는 정지). ./opsctl.sh logs 를 확인하세요."; }
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

# 점검이 SSH 에서 실패할 때, 어느 층에서 막혔는지 알려 준다. 이미지에는 nc·ping·ssh 가 없고
# python 만 있으므로 python 으로 확인한다. 컨테이너 안과 호스트에서 각각 보는 것이 핵심이다.
# 호스트는 되는데 컨테이너만 안 되면 브리지 네트워크 문제이고, 둘 다 안 되면 서버 밖 문제다.
#
# 판정은 마지막 줄의 NETCHECK=<코드> 로 주고받는다.  0 정상  2 이름 해석 실패  3 연결 실패  4 SSH 아님
# 종료 코드를 쓰지 않는 이유: nerdctl exec 는 컨테이너 명령의 종료 코드를 전달하지 않고
# 자기 자신이 1 로 끝나면서 level=fatal 줄을 찍는다. docker 는 그대로 전달한다. 런타임마다
# 다른 것에 판정을 걸면 nerdctl 서버에서만 엉뚱한 결론이 나온다.
netcheck)
    [ $# -ge 1 ] || die "확인할 노드 주소가 필요합니다.
  예: ./opsctl.sh netcheck 10.255.191.11
      ./opsctl.sh netcheck controller01 22"
    target="$1"
    target_port="${2:-22}"
    container_running || die "컨테이너가 실행 중이 아닙니다. ./opsctl.sh start 를 먼저 실행하세요."

    # 컨테이너와 호스트가 같은 검사를 하도록 스크립트를 한 번만 쓴다.
    probe_script="$BUNDLE_DIR/.netcheck.py"
    cat > "$probe_script" <<'PYEOF'
import socket, sys

host, port, where = sys.argv[1], int(sys.argv[2]), sys.argv[3]


def done(code):
    """판정을 마지막 줄로 알리고 끝낸다. 종료 코드는 런타임이 삼키므로 쓰지 않는다."""
    print("NETCHECK=%d" % code)
    raise SystemExit(0)

try:
    infos = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)
    addrs = sorted({i[4][0] for i in infos})
    print("  [OK] 이름 해석  %s -> %s" % (host, ", ".join(addrs)))
except OSError as exc:
    print("  [!] 이름 해석 실패  %s (%s)" % (host, exc))
    if where == "container":
        print("      컨테이너는 호스트의 /etc/hosts 를 물려받지 않습니다.")
    done(2)

addr = addrs[0]

# 어느 인터페이스로 나가는지. 10.4.x 로 나가면 브리지를 거쳐 NAT 된다는 뜻이다.
probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    probe.connect((addr, port))
    print("  [OK] 출발지 주소  %s" % probe.getsockname()[0])
except OSError as exc:
    print("  [!] 경로 없음  %s" % exc)
finally:
    probe.close()

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(5)
try:
    sock.connect((addr, port))
except socket.timeout:
    print("  [!] %s:%d 응답 없음 (5초 초과). 방화벽이 조용히 버리는 모양입니다." % (addr, port))
    done(3)
except OSError as exc:
    print("  [!] %s:%d 연결 실패  %s" % (addr, port, exc))
    done(3)

# 포트가 열렸다고 sshd 인 것은 아니다. 배너를 받아야 확인된다.
try:
    banner = sock.recv(128).decode("utf-8", "replace").strip()
except socket.timeout:
    print("  [!] %s:%d 는 열려 있지만 SSH 배너가 없습니다. sshd 가 아닌 다른 서비스입니다." % (addr, port))
    done(4)
except OSError as exc:
    print("  [!] 배너를 읽지 못했습니다  %s" % exc)
    done(4)
finally:
    sock.close()

if banner.startswith("SSH-"):
    print("  [OK] SSH 응답  %s" % banner)
    done(0)
print("  [!] 열려 있지만 SSH 가 아닙니다: %r" % banner[:60])
done(4)
PYEOF

    log ""
    log "네트워크 진단   $target:$target_port"
    log "=============================================="

    # 표식 줄은 화면에서 빼고 판정에만 쓴다.
    verdict_of() { awk -F= '/^NETCHECK=/{print $2}' "$1" | tail -1; }
    show()       { grep -v '^NETCHECK=' "$1" || true; }

    log ""
    log "[1/2] 컨테이너 안에서"
    out_in="$BUNDLE_DIR/.netcheck.in"
    rt exec -i "$CONTAINER_NAME" python - "$target" "$target_port" container < "$probe_script" > "$out_in" 2>/dev/null || true
    show "$out_in"
    in_rc="$(verdict_of "$out_in")"
    [ -n "$in_rc" ] || { in_rc=98; warn "컨테이너 안에서 검사를 실행하지 못했습니다."; }

    log ""
    log "[2/2] 호스트에서"
    out_host="$BUNDLE_DIR/.netcheck.host"
    if command -v python3 >/dev/null 2>&1; then
        python3 "$probe_script" "$target" "$target_port" host > "$out_host" 2>/dev/null || true
        show "$out_host"
        host_rc="$(verdict_of "$out_host")"
        [ -n "$host_rc" ] || host_rc=98
    else
        host_rc=99
        info "호스트에 python3 가 없어 건너뜁니다. 직접 확인하세요:"
        info "  ssh -p $target_port <계정>@$target"
    fi
    rm -f "$probe_script" "$out_in" "$out_host"

    log ""
    log "=============================================="
    if [ "$in_rc" = "0" ] && [ "$host_rc" = "0" ]; then
        ok "컨테이너에서 노드까지 닿습니다. 네트워크는 문제가 아닙니다."
        info "점검이 계속 실패하면 SSH 계정·키·호스트 키 승인·sudo 권한을 확인하세요."
        info "  [공급자 연결] > 연결 진단 이 같은 항목을 순서대로 확인해 줍니다."
    elif [ "$in_rc" = "2" ]; then
        warn "이름 해석에서 막혔습니다."
        info "컨테이너는 호스트의 /etc/hosts 를 물려받지 않습니다."
        info "  [공급자 연결] > 노드 인벤토리 에서 노드 IP 를 직접 넣거나 노드 탐색을 다시 실행하세요."
        info "  탐색은 Controller 에서 getent 로 IP 를 받아 저장하므로 보통 이것으로 해결됩니다."
    elif [ "$in_rc" != "0" ] && [ "$host_rc" = "0" ]; then
        warn "호스트에서는 닿는데 컨테이너에서만 막혔습니다. 브리지 네트워크 문제입니다."
        info "config.env 에 USE_HOST_NETWORK=yes 를 넣고 ./opsctl.sh restart 하세요."
        info "  (host 네트워크에서는 HOST_PORT 가 무시되고 8090 을 씁니다)"
    elif [ "$in_rc" != "0" ] && [ "$host_rc" = "99" ]; then
        warn "컨테이너에서 막혔습니다. 호스트 쪽은 확인하지 못했습니다."
        info "호스트에서 ssh -p $target_port <계정>@$target 이 되는지 먼저 보세요."
        info "  호스트는 되는데 컨테이너만 안 되면 USE_HOST_NETWORK=yes 로 해결됩니다."
    elif [ "$in_rc" = "4" ] || [ "$host_rc" = "4" ]; then
        warn "포트는 열려 있으나 SSH 가 아닙니다."
        info "노드의 SSH 포트가 $target_port 이 맞는지, 앞에 다른 장비가 있는지 확인하세요."
    else
        warn "이 서버에서 노드로 가는 경로가 없습니다. 컨테이너 문제가 아닙니다."
        info "서버 밖을 확인하세요: 라우팅, 방화벽·보안장비, 노드의 sshd 기동 여부."
        info "  ip route get $target"
    fi
    log ""
    ;;

backup)
    [ -d "$DATA_DIR" ] || die "데이터 디렉터리가 없습니다."
    target="${1:-$BUNDLE_DIR/backup/$APP_NAME-data-$(date +%Y%m%d-%H%M%S).tar.gz}"
    mkdir -p "$(dirname "$target")"
    umask 077
    partial="$(mktemp "$target.partial.XXXXXX")"
    was_running=no
    backup_cleanup() {
        backup_rc=$?
        trap - 0 HUP INT TERM
        rm -f "$partial"
        if [ "$was_running" = yes ]; then
            if rt start "$CONTAINER_NAME" >/dev/null && wait_healthy 10; then
                info "기존 서비스 재기동 완료"
            else
                warn "기존 서비스 재기동 실패. ./opsctl.sh logs 를 확인하세요."
                backup_rc=1
            fi
        fi
        exit "$backup_rc"
    }
    trap backup_cleanup 0
    trap 'exit 1' HUP INT TERM
    if container_running; then
        was_running=yes
        rt stop "$CONTAINER_NAME" >/dev/null
        info "일관성을 위해 잠시 정지"
    fi
    tar -czf "$partial" -C "$BUNDLE_DIR" data
    mv "$partial" "$target"
    ok "백업: $target ($(du -h "$target" | awk '{print $1}'))"
    warn "이 파일에는 자격증명을 푸는 마스터 키가 들어 있습니다. 접근 통제된 곳에 보관하세요."
    ;;

restore)
    [ $# -ge 1 ] || die "복원할 파일을 지정하세요: ./opsctl.sh restore <파일>"
    archive="$1"
    [ -f "$archive" ] || die "파일이 없습니다: $archive"
    archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"
    umask 077
    stage="$(mktemp -d "$BUNDLE_DIR/.restore.XXXXXX")"
    restore_cleanup() {
        restore_rc=$?
        trap - 0 HUP INT TERM
        rm -rf "$stage"
        exit "$restore_rc"
    }
    trap restore_cleanup 0
    trap 'exit 1' HUP INT TERM
    # Validate and extract before stopping the service or touching its data.
    if command -v python3 >/dev/null 2>&1; then
        python3 "$BUNDLE_DIR/restore_archive.py" "$archive" "$stage"
    else
        # The app image already contains Python. No host package installation needed.
        suffix="$(mount_suffix)"
        rt run --rm --network none --entrypoint python \
            --volume "$archive:/backup.tar.gz:ro${suffix:+,Z}" \
            --volume "$BUNDLE_DIR/restore_archive.py:/restore_archive.py:ro${suffix:+,Z}" \
            --volume "$stage:/restore$suffix" \
            "$IMAGE_REPO:$IMAGE_TAG" /restore_archive.py /backup.tar.gz /restore
    fi
    [ -d "$stage/data" ] || die "검증된 복원 데이터가 없습니다."
    prepare_replacement
    keep=""
    if [ -d "$DATA_DIR" ]; then
        keep="$(mktemp -d "$BUNDLE_DIR/data.before-restore.XXXXXX")"
        rmdir "$keep"
        mv "$DATA_DIR" "$keep"
        info "기존 데이터 보존: $keep"
    fi
    mv "$stage/data" "$DATA_DIR"
    start_container
    wait_healthy && ok "복원 후 기동 완료: $(server_url)" || { stop_failed_container; die "복원했지만 응답이 없습니다. 기존 데이터: $keep"; }
    ;;

remove)
    remove_owned_container
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

# --- systemd 유닛 ---------------------------------------------------------------------------
# 이 두 명령만 번들 디렉터리 밖(유닛 파일 하나)에 손을 댄다. 선택 사항이며, 무엇을 놓았는지
# installed-service.txt 에 적어 두고 uninstall-service 는 거기 적힌 것만 지운다.
#
# 서식을 손으로 sed 치던 절차를 대신한다. 자리표시자를 잘못 치면 systemd 가 경로를 절대경로가
# 아니라고 거부하는데(bad-setting), 그 원인은 journal 을 봐야 보인다. 여기서 미리 잡는다.

install-service)
    [ "$(id -u)" = "0" ] || die "root 권한이 필요합니다: sudo ./opsctl.sh install-service"
    command -v systemctl >/dev/null 2>&1 || die "systemd 가 없습니다. 이 서버에서는 유닛을 쓸 수 없습니다.
  docker 라면 --restart unless-stopped 로 재부팅 후에도 자동 기동됩니다."

    template="$BUNDLE_DIR/systemd/$APP_NAME.service.template"
    [ -f "$template" ] || die "유닛 서식이 없습니다: $template"

    unit="$UNIT_DIR/$CONTAINER_NAME.service"
    if [ -f "$unit" ] && ! grep -q "^$SERVICE_MARKER\$" "$unit"; then
        die "같은 이름의 유닛이 이미 있고 이 번들이 만든 것이 아닙니다: $unit
  남의 서비스를 덮어쓰지 않기 위해 중단합니다.
  이 유닛이 무엇인지 확인하거나, config.env 의 CONTAINER_NAME 을 다른 이름으로 바꾸세요."
    fi

    rendered="$BUNDLE_DIR/.unit.rendered"
    render_unit "$template" > "$rendered"

    # 치환이 제대로 됐는지 우리가 먼저 본다. 남은 자리표시자나 상대경로는 systemd 가
    # unit will not be started 로만 알려 주므로, 여기서 걸러 내는 편이 낫다.
    if grep -q '__BUNDLE_DIR__' "$rendered"; then
        rm -f "$rendered"
        die "유닛 서식의 자리표시자를 바꾸지 못했습니다. 서식이 손상됐는지 확인하세요: $template"
    fi
    for key in WorkingDirectory ExecStart ExecStop; do
        value="$(grep "^$key=" "$rendered" | head -n 1 | cut -d= -f2-)"
        case "$value" in
            /*) ;;
            *) rm -f "$rendered"; die "$key 가 절대경로가 아닙니다: $value" ;;
        esac
    done
    grep -q "^$SERVICE_MARKER\$" "$rendered" || {
        rm -f "$rendered"
        die "유닛 서식에 이 번들의 표식이 없습니다: $template"
    }

    mkdir -p "$UNIT_DIR"
    cat "$rendered" > "$unit"
    chmod 644 "$unit"
    rm -f "$rendered"
    printf '%s\n' "$unit" > "$SERVICE_RECORD"
    ok "유닛 설치: $unit"
    info "기록: $SERVICE_RECORD (uninstall-service 는 여기 적힌 것만 지웁니다)"

    systemctl daemon-reload
    systemctl enable "$CONTAINER_NAME" >/dev/null 2>&1 \
        || die "systemctl enable 실패: systemctl status $CONTAINER_NAME 을 확인하세요."
    ok "부팅 시 자동 기동 등록"

    if systemctl start "$CONTAINER_NAME"; then
        ok "기동 완료: $(server_url)"
    else
        warn "유닛은 설치했지만 기동에 실패했습니다."
        info "  systemctl status $CONTAINER_NAME --no-pager"
        info "  ./opsctl.sh logs"
        exit 1
    fi
    log ""
    log "  확인   systemctl status $CONTAINER_NAME --no-pager"
    log "  제거   sudo ./opsctl.sh uninstall-service"
    log ""
    ;;

uninstall-service)
    [ "$(id -u)" = "0" ] || die "root 권한이 필요합니다: sudo ./opsctl.sh uninstall-service"
    command -v systemctl >/dev/null 2>&1 || die "systemd 가 없습니다."

    if [ -f "$SERVICE_RECORD" ]; then
        unit="$(head -n 1 "$SERVICE_RECORD")"
    else
        unit="$UNIT_DIR/$CONTAINER_NAME.service"
    fi
    [ -f "$unit" ] || die "설치된 유닛이 없습니다: $unit"
    grep -q "^$SERVICE_MARKER\$" "$unit" \
        || die "이 번들이 만든 유닛이 아닙니다: $unit
  지우지 않고 중단합니다."

    # disable 만 한다. --now 를 붙이면 ExecStop 이 돌아 컨테이너까지 내려간다. 자동 기동만
    # 끄려던 운영자에게는 서비스가 멎는 것이 예상 밖의 결과다.
    systemctl disable "$(basename "$unit" .service)" >/dev/null 2>&1 || true
    rm -f "$unit"
    systemctl daemon-reload
    rm -f "$SERVICE_RECORD"
    ok "유닛 제거: $unit"
    info "컨테이너는 그대로 돌고 있습니다. 함께 내리려면 ./opsctl.sh stop"
    ;;

*)
    warn "알 수 없는 명령: $COMMAND"
    usage
    exit 1
    ;;
esac
