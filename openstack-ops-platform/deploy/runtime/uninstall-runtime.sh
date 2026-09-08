#!/bin/sh
# install-runtime.sh 가 설치한 것을 되돌린다.
#
#   ./uninstall-runtime.sh [--force]
#
# installed-manifest.txt 에 적힌 것만 지운다. 그 파일이 없으면 무엇을 지워야 할지 알 수 없으므로
# 아무것도 하지 않는다. 손으로 지우는 것보다 안전하다.

set -eu

BUNDLE_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$BUNDLE_DIR/installed-manifest.txt"
FORCE="no"
[ "${1:-}" = "--force" ] && FORCE="yes"

log()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  [OK] %s\n' "$*"; }
warn() { printf '  [!] %s\n' "$*" >&2; }
die()  { printf '\n[실패] %s\n' "$*" >&2; exit 1; }

log ""
log "컨테이너 런타임 제거"
log "=============================================="

[ "$(id -u)" = "0" ] || die "root 권한이 필요합니다. sudo 로 실행하세요."
[ -f "$MANIFEST" ] || die "설치 기록이 없습니다: $MANIFEST
  이 스크립트는 install-runtime.sh 가 설치한 것만 지웁니다.
  런타임을 다른 방법으로 설치했다면 그 방법으로 제거하세요."

PREFIX="$(awk -F= '/^PREFIX=/{print $2}' "$MANIFEST" | tail -1)"
PREFIX="${PREFIX:-/usr/local}"

# --- 돌고 있는 컨테이너 확인 ------------------------------------------------
log ""
log "[1/4] 남아 있는 컨테이너 확인"

running=""
if [ -x "$PREFIX/bin/nerdctl" ] && "$PREFIX/bin/nerdctl" info >/dev/null 2>&1; then
    for ns in $("$PREFIX/bin/nerdctl" namespace ls -q 2>/dev/null); do
        names="$("$PREFIX/bin/nerdctl" --namespace "$ns" ps --format '{{.Names}}' 2>/dev/null | tr -d '[]' | tr ' ,' '\n\n' | grep -v '^$' || true)"
        [ -n "$names" ] && running="$running $ns:$(printf '%s' "$names" | tr '\n' ',')"
    done
fi

if [ -n "$running" ]; then
    if [ "$FORCE" = "yes" ]; then
        warn "실행 중인 컨테이너가 있습니다:$running"
        warn "--force 가 지정되어 그대로 진행합니다. 이 컨테이너들은 멈춥니다."
    else
        die "아직 돌고 있는 컨테이너가 있습니다:$running
  런타임을 지우면 이 컨테이너들이 멈춥니다.
  플랫폼이라면 먼저 <플랫폼 번들>/opsctl.sh remove --all 을 실행하세요.
  그래도 지우려면 --force 를 붙이세요."
    fi
else
    ok "실행 중인 컨테이너 없음"
fi

# --- 서비스 정지 ------------------------------------------------------------
log ""
log "[2/4] containerd 정지"

if grep -q '^SERVICE=containerd$' "$MANIFEST"; then
    systemctl stop containerd >/dev/null 2>&1 || true
    systemctl disable containerd >/dev/null 2>&1 || true
    ok "containerd 정지·비활성화"
else
    info "설치 기록에 서비스가 없습니다. 건너뜁니다."
fi

# --- 파일 제거 --------------------------------------------------------------
log ""
log "[3/4] 파일 제거"

removed=0
missing=0
# 파일부터 지우고 빈 디렉터리는 뒤에서 정리한다.
awk -F= '/^FILE=/{sub(/^FILE=/, ""); print}' "$MANIFEST" | while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ -e "$path" ]; then rm -f "$path"; fi
done
removed="$(awk '/^FILE=/{n++} END{print n+0}' "$MANIFEST")"
ok "$removed 개 파일 제거"

# 우리가 만든 디렉터리 중 비어 있는 것만 지운다. 남의 파일이 있으면 그대로 둔다.
for d in "$PREFIX/libexec/cni" "$PREFIX/lib/systemd/system" "$PREFIX/lib/systemd" \
         "$PREFIX/share/doc/nerdctl" "$PREFIX/share/doc" "$PREFIX/libexec"; do
    [ -d "$d" ] && rmdir "$d" 2>/dev/null || true
done
info "빈 디렉터리 정리"

systemctl daemon-reload 2>/dev/null || true

# --- 커널 설정 복원 ---------------------------------------------------------
log ""
log "[4/4] 커널 설정 복원"

if grep -q '^SYSCTL_IP_FORWARD_WAS=0$' "$MANIFEST"; then
    sysctl -w net.ipv4.ip_forward=0 >/dev/null 2>&1 || true
    ok "net.ipv4.ip_forward 를 0 으로 되돌렸습니다."
else
    info "ip_forward 는 설치 전부터 켜져 있었으므로 그대로 둡니다."
fi

if grep -q '^SYSCTL_BRIDGE_NF_WAS=0$' "$MANIFEST"; then
    sysctl -w net.bridge.bridge-nf-call-iptables=0 >/dev/null 2>&1 || true
    ok "net.bridge.bridge-nf-call-iptables 를 0 으로 되돌렸습니다."
else
    info "bridge-nf-call-iptables 는 설치 전부터 켜져 있었으므로 그대로 둡니다."
fi

# 재부팅 유지용으로 넣은 /etc/sysctl.d·/etc/modules-load.d 파일은 위 [3/4] 에서 FILE= 목록으로
# 이미 지웠다. 모듈은 다음 부팅에 자동으로 올라오지 않는다. 지금 올라와 있는 것은 그대로 둔다.

# CNI 가 남긴 iptables 체인은 컨테이너를 지울 때 정리된다. 그래도 남은 것이 있으면 알린다.
if command -v iptables >/dev/null 2>&1; then
    orphan="$(iptables -t nat -S POSTROUTING 2>/dev/null | grep -c 'CNI-' || true)"
    if [ "${orphan:-0}" -gt 0 ]; then
        warn "iptables nat 테이블에 CNI 규칙이 $orphan 개 남아 있습니다."
        info "확인:  iptables -t nat -S POSTROUTING | grep CNI-"
        info "이 서버에서 다른 컨테이너 런타임을 쓰지 않는다면 지워도 됩니다."
    fi
fi

mv "$MANIFEST" "$MANIFEST.removed" 2>/dev/null || true

log ""
log "=============================================="
log "런타임 제거 완료"
log ""
info "설치 기록은 $MANIFEST.removed 로 남겨 두었습니다."
log ""
