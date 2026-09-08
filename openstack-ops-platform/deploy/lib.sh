#!/bin/sh
# 공통 함수. install.sh 와 opsctl.sh 가 함께 읽는다.
# 폐쇄망 서버의 셸이 bash 라는 보장이 없어 POSIX sh 로 작성한다.

set -eu

APP_NAME="openstack-ops-platform"
IMAGE_REPO="okestro/openstack-ops-platform"
NERDCTL_NAMESPACE="openstack-ops"

BUNDLE_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$BUNDLE_DIR/data"
CONFIG_FILE="$BUNDLE_DIR/config.env"

log()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  [OK] %s\n' "$*"; }
warn() { printf '  [!] %s\n' "$*" >&2; }
die()  { printf '\n[실패] %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 컨테이너 런타임 감지
#
# docker, podman, nerdctl 순으로 찾는다. 폐쇄망 서버마다 무엇이 깔려 있을지 모르기 때문에
# 하나로 못 박지 않는다. nerdctl 은 k8s 노드에 함께 깔려 있는 경우가 많으므로 전용
# namespace 를 써서 노드의 기존 이미지·컨테이너와 섞이지 않게 한다.
# ---------------------------------------------------------------------------
detect_runtime() {
    if [ -n "${OPS_RUNTIME:-}" ]; then
        command -v "$OPS_RUNTIME" >/dev/null 2>&1 || die "OPS_RUNTIME=$OPS_RUNTIME 을 찾을 수 없습니다."
        RUNTIME="$OPS_RUNTIME"
    else
        RUNTIME=""
        for candidate in docker podman nerdctl; do
            if command -v "$candidate" >/dev/null 2>&1; then RUNTIME="$candidate"; break; fi
        done
        [ -n "$RUNTIME" ] || die "docker, podman, nerdctl 중 어느 것도 없습니다.
  설치된 런타임이 다른 이름이라면 OPS_RUNTIME=<명령> 으로 지정해 다시 실행하세요."
    fi

    if [ "$RUNTIME" = "nerdctl" ]; then
        RUNTIME_ARGS="--namespace $NERDCTL_NAMESPACE"
    else
        RUNTIME_ARGS=""
    fi

    # 데몬이 실제로 응답하는지. docker 는 깔려 있어도 소켓 권한이 없으면 여기서 걸린다.
    if ! $RUNTIME $RUNTIME_ARGS info >/dev/null 2>&1; then
        die "$RUNTIME 이(가) 응답하지 않습니다.
  데몬이 떠 있는지(systemctl status docker), 현재 계정에 권한이 있는지 확인하세요.
  root 가 아니라면 sudo 로 실행하거나 계정을 docker 그룹에 넣어야 합니다."
    fi
}

rt() { $RUNTIME $RUNTIME_ARGS "$@"; }

# SELinux 가 enforcing 이면 바인드 마운트에 :Z 가 없을 때 컨테이너가 data 디렉터리를 못 읽는다.
# RHEL·Rocky 계열에서 흔한 함정이라 자동으로 붙인다.
mount_suffix() {
    if [ "$RUNTIME" = "nerdctl" ]; then printf ''; return; fi
    if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
        printf ':Z'
    else
        printf ''
    fi
}

load_config() {
    [ -f "$CONFIG_FILE" ] || die "설정 파일이 없습니다: $CONFIG_FILE
  install.sh 를 먼저 실행하세요."
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
    HOST_PORT="${HOST_PORT:-8090}"
    CONTAINER_NAME="${CONTAINER_NAME:-$APP_NAME}"
    IMAGE_TAG="${IMAGE_TAG:-}"
    [ -n "$IMAGE_TAG" ] || die "config.env 에 IMAGE_TAG 가 없습니다."
}

# nerdctl 은 이름을 `[name]` 으로, 이름이 여럿이면 `[a b]` 로 찍는다. docker·podman 은 그냥 name 이다.
# 대괄호를 떼고 한 줄에 하나씩 펼쳐서 세 런타임을 같은 방식으로 다룬다. 이 처리를 빼면
# nerdctl 에서 "컨테이너 없음"으로 잘못 판단해 restart 가 이름 충돌로 실패한다.
container_names() {
    rt ps "$@" --format '{{.Names}}' 2>/dev/null | tr -d '[]' | tr ' ,' '\n\n' | grep -v '^$' || true
}

container_exists() { container_names -a | grep -qx "$CONTAINER_NAME"; }
container_running() { container_names | grep -qx "$CONTAINER_NAME"; }

start_container() {
    suffix="$(mount_suffix)"
    mkdir -p "$DATA_DIR"

    set -- \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        --volume "$DATA_DIR:/app/data$suffix" \
        --env "TZ=${TIMEZONE:-Asia/Seoul}" \
        --env "INSPECTION_TIMEZONE=${TIMEZONE:-Asia/Seoul}" \
        --env "ADMIN_USERNAME=${ADMIN_USERNAME:-admin}" \
        --env "ADMIN_PASSWORD=${ADMIN_PASSWORD:-}" \
        --env "ADMIN_PASSWORD_RESET=${ADMIN_PASSWORD_RESET:-}" \
        --env "SESSION_TTL_HOURS=${SESSION_TTL_HOURS:-8}"

    # 점검 대상 노드로 SSH 를 나가야 하므로 컨테이너에서 사설망이 보여야 한다.
    # 브리지 네트워크로 나가지 못하는 환경에서는 config.env 의 USE_HOST_NETWORK=yes 로 바꾼다.
    # host 네트워크에서는 컨테이너가 호스트 포트를 그대로 쓰므로 --publish 를 주면 안 된다.
    if [ "${USE_HOST_NETWORK:-no}" = "yes" ]; then
        set -- "$@" --network host
    else
        set -- "$@" --publish "${BIND_ADDRESS:-0.0.0.0}:$HOST_PORT:8090"
    fi

    rt run --detach "$@" "$IMAGE_REPO:$IMAGE_TAG" >/dev/null
}

# host 네트워크에서는 컨테이너 포트가 곧 호스트 포트다.
effective_port() {
    if [ "${USE_HOST_NETWORK:-no}" = "yes" ]; then printf '8090'; else printf '%s' "$HOST_PORT"; fi
}

# wait_healthy [최대 대기 초]. 기동 직후에는 넉넉히, 단순 조회에서는 짧게 쓴다.
wait_healthy() {
    url="http://127.0.0.1:$(effective_port)/api/health"
    limit="${1:-60}"
    i=0
    while [ "$i" -lt "$limit" ]; do
        if command -v curl >/dev/null 2>&1; then
            curl -sf "$url" >/dev/null 2>&1 && return 0
        else
            # 폐쇄망 최소 설치 서버에는 curl 이 없을 수 있다. 컨테이너 안의 python 으로 확인한다.
            rt exec "$CONTAINER_NAME" python -c \
                "import urllib.request;urllib.request.urlopen('http://127.0.0.1:8090/api/health')" \
                >/dev/null 2>&1 && return 0
        fi
        i=$((i + 1))
        sleep 1
    done
    return 1
}

server_url() {
    host="${ACCESS_HOST:-}"
    if [ -z "$host" ]; then
        host="$(hostname -I 2>/dev/null | awk '{print $1}')"
        [ -n "$host" ] || host="$(hostname)"
    fi
    printf 'http://%s:%s/' "$host" "$(effective_port)"
}
