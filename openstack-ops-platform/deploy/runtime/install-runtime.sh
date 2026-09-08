#!/bin/sh
# 컨테이너 런타임 설치 (폐쇄망)
#
#   ./install-runtime.sh [옵션]
#
# containerd·runc·CNI 플러그인·nerdctl 을 설치한다. 배포판 패키지를 쓰지 않고 정적 바이너리를
# 풀어 놓으므로 RHEL·Rocky·Ubuntu 어디서든 같은 방식으로 동작한다. 인터넷은 쓰지 않는다.
#
# 이 스크립트는 플랫폼 번들과 달리 **시스템을 고친다**. 무엇을 고쳤는지 manifest 에 남기고
# ./uninstall-runtime.sh 로 그대로 되돌린다.
#
# 옵션
#   --force              이미 런타임이 있어도 설치를 진행한다
#   --cni-subnet CIDR    컨테이너 브리지 대역을 지정한다 (기본 10.4.0.0/24)
#   --no-bridge          브리지 네트워크를 설정하지 않는다 (host 네트워크만 쓸 때)
#   --prefix DIR         설치 위치 (기본 /usr/local)
#   --no-persist         커널 모듈·파라미터를 재부팅 뒤까지 유지하지 않는다

set -eu

BUNDLE_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="/usr/local"
# 배치 위치는 환경 변수로 바꿀 수 있다. 시스템 경로가 다른 서버와 회귀 테스트를 위한 것으로,
# 보통은 건드리지 않는다.
UNIT_DIR="${OPS_UNIT_DIR:-/etc/systemd/system}"
CNI_CONF_DIR="${OPS_CNI_CONF_DIR:-/etc/cni/net.d}"
IP_FORWARD_PATH="${OPS_IP_FORWARD_PATH:-/proc/sys/net/ipv4/ip_forward}"
BRIDGE_NF_PATH="${OPS_BRIDGE_NF_PATH:-/proc/sys/net/bridge/bridge-nf-call-iptables}"
SYSCTL_DIR="${OPS_SYSCTL_DIR:-/etc/sysctl.d}"
MODULES_DIR="${OPS_MODULES_DIR:-/etc/modules-load.d}"
MANIFEST="$BUNDLE_DIR/installed-manifest.txt"
CNI_SUBNET="10.4.0.0/24"
FORCE="no"
SETUP_BRIDGE="yes"
PERSIST="yes"

log()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  [OK] %s\n' "$*"; }
warn() { printf '  [!] %s\n' "$*" >&2; }
die()  { printf '\n[실패] %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --force) FORCE="yes" ;;
        --cni-subnet) shift; [ $# -gt 0 ] || die "--cni-subnet 뒤에 CIDR 이 필요합니다."; CNI_SUBNET="$1" ;;
        --no-bridge) SETUP_BRIDGE="no" ;;
        --no-persist) PERSIST="no" ;;
        --prefix) shift; [ $# -gt 0 ] || die "--prefix 뒤에 경로가 필요합니다."; PREFIX="$1" ;;
        -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
        *) die "알 수 없는 옵션: $1" ;;
    esac
    shift
done

log ""
log "컨테이너 런타임 설치"
log "=============================================="

# --- 1. 실행 환경 -----------------------------------------------------------
log ""
log "[1/7] 실행 환경 확인"

[ "$(id -u)" = "0" ] || die "root 권한이 필요합니다. sudo 로 실행하세요."
ok "root 권한"

arch="$(uname -m)"
case "$arch" in
    x86_64|amd64) ok "아키텍처 $arch" ;;
    *) die "이 번들은 x86_64 전용입니다. 이 서버는 $arch 입니다." ;;
esac

command -v systemctl >/dev/null 2>&1 || die "systemd 가 없습니다. 이 스크립트는 systemd 서버를 전제로 합니다."
ok "systemd"

# iptables 는 컨테이너 포트 매핑(portmap 의 DNAT)과 마스커레이딩에 필요하다. 없으면 브리지
# 네트워크는 조용히 반쪽만 동작한다. 화면은 열리지 않고 점검은 노드에 닿지 못한다.
# 폐쇄망 서버는 패키지를 새로 설치할 수 없으므로, 나중에 알게 하지 말고 여기서 멈춘다.
if command -v iptables >/dev/null 2>&1; then
    ok "iptables"
elif [ "$SETUP_BRIDGE" = "yes" ] && [ "$FORCE" = "no" ]; then
    die "iptables 가 없습니다. 브리지 네트워크의 포트 매핑과 NAT 이 동작하지 않습니다.
  --no-bridge 로 설치하고 플랫폼을 config.env 의 USE_HOST_NETWORK=yes 로 쓰거나,
  iptables 를 먼저 설치하세요. 그래도 진행하려면 --force 를 붙이세요."
elif [ "$SETUP_BRIDGE" = "yes" ]; then
    warn "iptables 가 없습니다. --force 로 진행하지만 브리지 네트워크는 동작하지 않습니다."
else
    info "iptables 없음. --no-bridge 이므로 필요하지 않습니다."
fi

# overlayfs 는 컨테이너 파일시스템의 기본 스냅샷터다.
if modprobe overlay 2>/dev/null || grep -q overlay /proc/filesystems 2>/dev/null; then
    ok "overlayfs"
else
    warn "overlay 모듈을 올리지 못했습니다. containerd 기동에 실패할 수 있습니다."
fi

# --- 2. 이미 설치된 런타임 --------------------------------------------------
log ""
log "[2/7] 기존 런타임 확인"

existing=""
for candidate in docker podman nerdctl containerd; do
    if command -v "$candidate" >/dev/null 2>&1; then
        existing="$existing $candidate($(command -v "$candidate"))"
    fi
done

if [ -n "$existing" ]; then
    if [ "$FORCE" = "yes" ]; then
        warn "이미 런타임이 있습니다:$existing"
        warn "--force 가 지정되어 그대로 진행합니다. 기존 바이너리를 덮어쓸 수 있습니다."
    else
        die "이 서버에는 이미 컨테이너 런타임이 있습니다:$existing
  덮어쓰면 그 런타임으로 돌고 있는 컨테이너가 멈출 수 있으므로 설치를 중단합니다.
  기존 런타임을 그대로 쓰려면 이 스크립트를 실행하지 말고 플랫폼 번들의 ./install.sh 만 실행하세요.
  그래도 설치하려면 --force 를 붙이세요."
    fi
else
    ok "설치된 런타임 없음"
fi

# --- 3. 무결성 --------------------------------------------------------------
log ""
log "[3/7] 파일 무결성"

archive=""
for f in "$BUNDLE_DIR"/nerdctl-full-*-linux-amd64.tar.gz; do
    [ -f "$f" ] && archive="$f"
done
[ -n "$archive" ] || die "런타임 파일이 없습니다: $BUNDLE_DIR/nerdctl-full-*-linux-amd64.tar.gz
  번들이 온전히 풀렸는지 확인하세요."
info "$(basename "$archive")"

if [ -f "$BUNDLE_DIR/SHA256SUMS" ] && command -v sha256sum >/dev/null 2>&1; then
    # 상위 배포처가 배포한 SHA256SUMS 원본을 그대로 쓴다. 우리가 다시 계산한 값이 아니다.
    ( cd "$BUNDLE_DIR" && grep " $(basename "$archive")\$" SHA256SUMS | sha256sum -c - >/dev/null 2>&1 ) \
        && ok "체크섬 확인 (상위 배포처 SHA256SUMS 기준)" \
        || die "체크섬이 맞지 않습니다. 전송 중 손상됐거나 파일이 바뀌었습니다. 다시 반입하세요."
else
    warn "SHA256SUMS 또는 sha256sum 이 없어 무결성 검증을 건너뜁니다."
fi

# --- 4. 덮어쓸 파일 확인 ----------------------------------------------------
log ""
log "[4/7] 설치 대상 확인"

overwrite=""
for path in $(tar -tzf "$archive" | grep -vE '/$'); do
    [ -e "$PREFIX/$path" ] && overwrite="$overwrite $PREFIX/$path"
done
if [ -n "$overwrite" ]; then
    count="$(printf '%s' "$overwrite" | tr ' ' '\n' | grep -c . || true)"
    if [ "$FORCE" = "yes" ]; then
        warn "$count 개 파일을 덮어씁니다."
    else
        die "$PREFIX 에 같은 이름의 파일이 $count 개 있습니다. 덮어쓰지 않고 중단합니다.
  예: $(printf '%s' "$overwrite" | tr ' ' '\n' | grep -v '^$' | head -3 | tr '\n' ' ')
  --prefix 로 다른 위치에 설치하거나 --force 를 붙이세요."
    fi
else
    ok "덮어쓸 파일 없음"
fi

# --- 5. 설치 ----------------------------------------------------------------
log ""
log "[5/7] 파일 설치"

mkdir -p "$PREFIX"
tar -xzf "$archive" -C "$PREFIX"
ok "$PREFIX 에 풀었습니다 (bin, libexec/cni, lib/systemd)"

# 설치한 것을 기록해 둔다. uninstall 이 이 목록만 지운다.
{
    printf '# 이 파일은 install-runtime.sh 가 만든 설치 기록입니다. 지우지 마세요.\n'
    printf '# 설치 시각: %s\n' "$(date -Is 2>/dev/null || date)"
    printf 'PREFIX=%s\n' "$PREFIX"
    printf 'ARCHIVE=%s\n' "$(basename "$archive")"
    tar -tzf "$archive" | grep -vE '/$' | sed "s#^#FILE=$PREFIX/#"
} > "$MANIFEST"
ok "설치 기록: $MANIFEST"

# systemd 유닛. 배포판에 따라 /usr/local/lib/systemd/system 을 읽지 않으므로 /etc 로 복사한다.
if [ -f "$PREFIX/lib/systemd/system/containerd.service" ]; then
    cp "$PREFIX/lib/systemd/system/containerd.service" "$UNIT_DIR/containerd.service"
    printf 'FILE=%s\n' "$UNIT_DIR/containerd.service" >> "$MANIFEST"
    ok "$UNIT_DIR/containerd.service"
else
    die "번들 안에 containerd.service 가 없습니다."
fi

# --- 6. 네트워크 ------------------------------------------------------------
log ""
log "[6/7] 네트워크 설정"

if [ "$SETUP_BRIDGE" = "no" ]; then
    info "--no-bridge 지정. 브리지 설정을 건너뜁니다."
    info "플랫폼은 config.env 의 USE_HOST_NETWORK=yes 로 실행하세요."
else
    # 컨테이너에서 점검 대상 노드로 나가려면 포워딩이 켜져 있어야 한다.
    # 커널 설정을 바꾸는 유일한 곳이므로 원래 값을 기록해 둔다.
    if [ "$(cat "$IP_FORWARD_PATH" 2>/dev/null || echo 0)" = "1" ]; then
        ok "net.ipv4.ip_forward=1 (이미 켜져 있음)"
    else
        printf 'SYSCTL_IP_FORWARD_WAS=0\n' >> "$MANIFEST"
        sysctl -w net.ipv4.ip_forward=1 >/dev/null
        warn "net.ipv4.ip_forward 를 1 로 바꿨습니다 (컨테이너 → 점검 대상 노드 통신에 필요)."
    fi

    # 브리지를 지나는 패킷에 iptables 규칙(포트 매핑 DNAT, 마스커레이딩)이 적용되려면
    # br_netfilter 가 올라와 있고 bridge-nf-call-iptables 가 1 이어야 한다. 배포판 기본값은
    # 서버마다 다르고, 꺼져 있으면 컨테이너 포트로 들어온 요청이 조용히 사라진다.
    modprobe br_netfilter 2>/dev/null || true
    if [ -f "$BRIDGE_NF_PATH" ]; then
        if [ "$(cat "$BRIDGE_NF_PATH" 2>/dev/null || echo 0)" = "1" ]; then
            ok "net.bridge.bridge-nf-call-iptables=1 (이미 켜져 있음)"
        else
            printf 'SYSCTL_BRIDGE_NF_WAS=0\n' >> "$MANIFEST"
            sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null 2>&1 || true
            ok "net.bridge.bridge-nf-call-iptables 를 1 로 바꿨습니다 (컨테이너 포트 매핑에 필요)."
        fi
    else
        warn "br_netfilter 모듈이 없어 bridge-nf-call-iptables 를 확인하지 못했습니다."
        info "컨테이너 포트로 접속이 안 되면 이 모듈을 먼저 확인하세요."
    fi

    # 기본 대역이 이 서버의 기존 경로와 겹치면 점검 대상 노드로 가는 트래픽이 브리지로 새어 나간다.
    # 실제로 사이트 관리망이 10/8 인 경우가 흔하다.
    # 겹침 판정은 POSIX awk 산술로만 한다. and() 는 gawk 전용이라 Ubuntu 의 mawk 에서 죽는다.
    # 두 대역은 짧은 쪽 prefix 길이로 잘랐을 때 같은 블록이면 겹친다.
    conflict="$(ip -o route show 2>/dev/null | awk -v target="$CNI_SUBNET" '
        function ip2int(s,   a) { split(s, a, "."); return a[1]*16777216 + a[2]*65536 + a[3]*256 + a[4] }
        BEGIN { split(target, t, "/"); tnet = ip2int(t[1]); tlen = t[2] + 0 }
        $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$/ {
            split($1, r, "/"); rnet = ip2int(r[1]); rlen = r[2] + 0
            len = (tlen < rlen ? tlen : rlen)
            block = 2 ^ (32 - len)
            if (int(tnet / block) == int(rnet / block)) print $1
        }' 2>/dev/null || true)"

    if [ -n "$conflict" ]; then
        die "컨테이너 브리지 대역 $CNI_SUBNET 이 이 서버의 기존 경로와 겹칩니다: $conflict
  그대로 두면 점검 대상 노드로 가는 트래픽이 브리지로 새어 나갑니다.
  --cni-subnet 으로 겹치지 않는 대역을 지정하거나(예: --cni-subnet 172.31.240.0/24),
  --no-bridge 로 설치한 뒤 플랫폼을 USE_HOST_NETWORK=yes 로 쓰세요."
    fi
    ok "브리지 대역 $CNI_SUBNET (기존 경로와 겹치지 않음)"

    gateway="$(printf '%s' "$CNI_SUBNET" | awk -F'[./]' '{print $1"."$2"."$3".1"}')"
    if [ -f "$CNI_CONF_DIR/nerdctl-bridge.conflist" ]; then
        info "$CNI_CONF_DIR/nerdctl-bridge.conflist 가 이미 있어 그대로 둡니다."
    else
        mkdir -p "$CNI_CONF_DIR"
        cat > "$CNI_CONF_DIR/nerdctl-bridge.conflist" <<CNI
{
  "cniVersion": "1.0.0",
  "name": "bridge",
  "nerdctlLabels": { "nerdctl/default-network": "true" },
  "plugins": [
    {
      "type": "bridge",
      "bridge": "nerdctl0",
      "isGateway": true,
      "ipMasq": true,
      "hairpinMode": true,
      "ipam": {
        "type": "host-local",
        "ranges": [ [ { "subnet": "$CNI_SUBNET", "gateway": "$gateway" } ] ],
        "routes": [ { "dst": "0.0.0.0/0" } ]
      }
    },
    { "type": "portmap", "capabilities": { "portMappings": true } },
    { "type": "firewall", "ingressPolicy": "same-bridge" },
    { "type": "tuning" }
  ]
}
CNI
        printf 'FILE=%s\n' "$CNI_CONF_DIR/nerdctl-bridge.conflist" >> "$MANIFEST"
        ok "$CNI_CONF_DIR/nerdctl-bridge.conflist ($CNI_SUBNET)"
    fi
fi

# 재부팅 뒤에도 유지한다. 모듈과 커널 파라미터는 지금 값만 바꿔서는 다음 부팅에 되돌아가고,
# 그러면 컨테이너는 뜨는데 점검만 안 되는 상태가 된다. 원인을 찾기 어려운 종류의 고장이다.
# 우리가 만든 파일이므로 manifest 에 적고 제거 때 지운다.
if [ "$PERSIST" = "yes" ]; then
    mkdir -p "$MODULES_DIR"
    {
        printf '# openstack-ops-platform 런타임이 만든 파일입니다.\n'
        printf 'overlay\n'
        [ "$SETUP_BRIDGE" = "yes" ] && printf 'br_netfilter\n'
    } > "$MODULES_DIR/openstack-ops-runtime.conf"
    printf 'FILE=%s\n' "$MODULES_DIR/openstack-ops-runtime.conf" >> "$MANIFEST"
    ok "$MODULES_DIR/openstack-ops-runtime.conf"

    if [ "$SETUP_BRIDGE" = "yes" ]; then
        mkdir -p "$SYSCTL_DIR"
        {
            printf '# openstack-ops-platform 런타임이 만든 파일입니다.\n'
            printf 'net.ipv4.ip_forward = 1\n'
            printf 'net.bridge.bridge-nf-call-iptables = 1\n'
        } > "$SYSCTL_DIR/99-openstack-ops-runtime.conf"
        printf 'FILE=%s\n' "$SYSCTL_DIR/99-openstack-ops-runtime.conf" >> "$MANIFEST"
        ok "$SYSCTL_DIR/99-openstack-ops-runtime.conf"
    fi
else
    info "--no-persist 지정. 모듈·커널 파라미터는 재부팅 시 원래대로 돌아갑니다."
fi

# --- 7. 기동 확인 -----------------------------------------------------------
log ""
log "[7/7] containerd 기동"

systemctl daemon-reload
systemctl enable containerd >/dev/null 2>&1 || true
systemctl restart containerd
printf 'SERVICE=containerd\n' >> "$MANIFEST"

i=0
while [ "$i" -lt 30 ]; do
    if "$PREFIX/bin/nerdctl" info >/dev/null 2>&1; then break; fi
    i=$((i + 1))
    sleep 1
done

"$PREFIX/bin/nerdctl" info >/dev/null 2>&1 || {
    systemctl status containerd --no-pager 2>&1 | sed 's/^/    /' >&2
    die "containerd 가 응답하지 않습니다. 위 상태를 확인하세요."
}
ok "containerd $("$PREFIX/bin/containerd" --version 2>/dev/null | awk '{print $3}')"
ok "nerdctl $("$PREFIX/bin/nerdctl" --version 2>/dev/null | awk '{print $3}')"
ok "runc $("$PREFIX/bin/runc" --version 2>/dev/null | head -1 | awk '{print $3}')"

log ""
log "=============================================="
log "런타임 설치 완료"
log ""
if ! printf '%s' "$PATH" | tr ':' '\n' | grep -qx "$PREFIX/bin"; then
    warn "$PREFIX/bin 이 PATH 에 없습니다. 다음 명령을 실행하거나 새로 로그인하세요."
    log "    export PATH=\$PATH:$PREFIX/bin"
    log ""
fi
log "  이제 플랫폼 번들을 설치하세요."
log "    cd <플랫폼 번들 디렉터리> && ./install.sh"
log ""
log "  되돌리기    ./uninstall-runtime.sh"
log "  설치 기록   $MANIFEST"
log ""
