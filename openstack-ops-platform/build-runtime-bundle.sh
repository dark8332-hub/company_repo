#!/usr/bin/env bash
# 컨테이너 런타임이 없는 폐쇄망 서버용 번들을 만든다.
#
#   ./build-runtime-bundle.sh [nerdctl 버전]
#
# 결과: dist/openstack-ops-runtime-<버전>-offline.tar.gz
#
# 상위 배포처(containerd/nerdctl)의 nerdctl-full 압축 파일을 손대지 않고 그대로 넣는다.
# 우리가 다시 묶으면 사이트에서 상위 배포처의 SHA256SUMS 로 검증할 수 없기 때문이다.
set -euo pipefail

VERSION="${1:-2.3.5}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/dist/runtime-src"
NAME="openstack-ops-runtime-$VERSION"
STAGING="$ROOT/dist/$NAME"
ARCHIVE="nerdctl-full-$VERSION-linux-amd64.tar.gz"
BASE_URL="https://github.com/containerd/nerdctl/releases/download/v$VERSION"

cd "$ROOT"
mkdir -p "$SRC"

echo
echo "[1/4] 상위 배포처 파일"
if [ ! -f "$SRC/$ARCHIVE" ]; then
    echo "  내려받는 중: $ARCHIVE"
    curl -sSL -o "$SRC/$ARCHIVE" "$BASE_URL/$ARCHIVE"
fi
if [ ! -f "$SRC/SHA256SUMS" ]; then
    curl -sSL -o "$SRC/SHA256SUMS" "$BASE_URL/SHA256SUMS"
fi
( cd "$SRC" && grep " $ARCHIVE\$" SHA256SUMS | sha256sum -c - >/dev/null ) \
    || { echo "  상위 배포처 체크섬 불일치. 중단합니다." >&2; exit 1; }
echo "  [OK] $ARCHIVE ($(du -h "$SRC/$ARCHIVE" | awk '{print $1}')) - 상위 배포처 SHA256SUMS 검증"

echo
echo "[2/4] 번들 구성"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp "$SRC/$ARCHIVE" "$STAGING/"
# SHA256SUMS 는 릴리스 전체를 담고 있다. 우리가 넣은 파일 줄만 남겨 사이트에서 혼동이 없게 한다.
grep " $ARCHIVE\$" "$SRC/SHA256SUMS" > "$STAGING/SHA256SUMS"
cp "$ROOT/deploy/runtime/install-runtime.sh" "$STAGING/"
cp "$ROOT/deploy/runtime/uninstall-runtime.sh" "$STAGING/"
cp "$ROOT/deploy/runtime/README-RUNTIME.md" "$STAGING/"
chmod +x "$STAGING/install-runtime.sh" "$STAGING/uninstall-runtime.sh"

{
    echo "openstack-ops-platform 런타임 번들"
    echo "nerdctl    v$VERSION (nerdctl-full: containerd + runc + CNI + nerdctl)"
    echo "빌드 시각  $(date -Is)"
    echo "빌드 호스트 $(hostname)"
    echo "대상       linux/amd64"
} > "$STAGING/VERSION"
echo "  [OK] $STAGING"

echo
echo "[3/4] 스크립트 문법 검사"
sh -n "$STAGING/install-runtime.sh"
sh -n "$STAGING/uninstall-runtime.sh"
echo "  [OK] install-runtime.sh, uninstall-runtime.sh"

echo
echo "[4/4] 압축"
( cd "$ROOT/dist" && tar -czf "$NAME-offline.tar.gz" "$NAME" )
( cd "$ROOT/dist" && sha256sum "$NAME-offline.tar.gz" > "$NAME-offline.tar.gz.sha256" )
echo "  [OK] dist/$NAME-offline.tar.gz ($(du -h "$ROOT/dist/$NAME-offline.tar.gz" | awk '{print $1}'))"

echo
echo "=============================================="
echo "런타임 번들 완성"
echo
echo "  dist/$NAME-offline.tar.gz"
echo "  dist/$NAME-offline.tar.gz.sha256"
echo
echo "  런타임이 없는 서버에서만 씁니다. 있으면 플랫폼 번들만 반입하세요."
echo
