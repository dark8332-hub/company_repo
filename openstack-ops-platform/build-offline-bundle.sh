#!/usr/bin/env bash
# 폐쇄망 반입용 배포 번들을 만든다. 인터넷이 되는 이 서버에서 실행한다.
#
#   ./build-offline-bundle.sh [버전]
#
# 결과: dist/openstack-ops-platform-<버전>-offline.tar.gz
#
# 이미지는 docker-archive 형식으로 저장하므로 docker, podman, nerdctl 어디서든 load 된다.
set -euo pipefail


APP="openstack-ops-platform"
IMAGE="okestro/$APP"
ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:-$(cat "$ROOT/VERSION")}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || { echo "잘못된 버전: $VERSION" >&2; exit 1; }
REVISION="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf unknown)"
SOURCE_DIRTY=false
[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=normal -- . 2>/dev/null)" ] || SOURCE_DIRTY=true
BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STAGING="$ROOT/dist/$APP-$VERSION"
NS="openstack-ops-build"

cd "$ROOT"

# --- 빌드 도구 -------------------------------------------------------------
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    BUILDER="docker"; BUILDER_ARGS=()
elif command -v nerdctl >/dev/null 2>&1 && nerdctl --namespace "$NS" info >/dev/null 2>&1; then
    # k8s 노드에 nerdctl 이 있는 경우가 많다. 전용 namespace 를 써서 노드의 이미지와 섞지 않는다.
    BUILDER="nerdctl"; BUILDER_ARGS=(--namespace "$NS")
elif command -v podman >/dev/null 2>&1; then
    BUILDER="podman"; BUILDER_ARGS=()
else
    echo "docker, nerdctl, podman 중 어느 것도 쓸 수 없습니다." >&2
    exit 1
fi
echo "빌더: $BUILDER ${BUILDER_ARGS[*]:-}"

build() { "$BUILDER" "${BUILDER_ARGS[@]}" "$@"; }

# --- 번들에 들어갈 것이 다 있는지 -----------------------------------------
echo
echo "[1/5] 사전 검사"
if [ -x .venv/bin/python ]; then
    .venv/bin/python -m pytest tests/test_offline_packaging.py tests/test_deploy_scripts.py tests/test_release_safety.py -q \
        || { echo "오프라인 패키징 검사 실패. 고치고 다시 실행하세요." >&2; exit 1; }
    echo "  [OK] 오프라인 패키징 검사"
else
    echo "  [!] .venv 가 없어 검사를 건너뜁니다." >&2
fi

# --- 이미지 ---------------------------------------------------------------
echo
echo "[2/5] 이미지 빌드"
build build --platform linux/amd64 \
    --build-arg "APP_VERSION=$VERSION" --build-arg "VCS_REF=$REVISION" \
    --build-arg "BUILD_TIME=$BUILD_TIME" --build-arg "SOURCE_DIRTY=$SOURCE_DIRTY" \
    -t "$IMAGE:$VERSION" -t "$IMAGE:latest" . >/dev/null
echo "  [OK] $IMAGE:$VERSION"

echo
echo "[3/5] 이미지 저장"
rm -rf "$STAGING"
mkdir -p "$STAGING/image"
build save -o "$STAGING/image/$APP-$VERSION.tar" "$IMAGE:$VERSION"
( cd "$STAGING/image" && sha256sum "$APP-$VERSION.tar" > SHA256SUMS )
echo "  [OK] $(du -h "$STAGING/image/$APP-$VERSION.tar" | awk '{print $1}')"

# --- 스크립트와 문서 -------------------------------------------------------
echo
echo "[4/5] 번들 구성"
cp deploy/install.sh deploy/opsctl.sh deploy/lib.sh deploy/restore_archive.py "$STAGING/"
cp deploy/README-DEPLOY.md "$STAGING/"
mkdir -p "$STAGING/systemd"
cp deploy/systemd/openstack-ops-platform.service.template "$STAGING/systemd/"
sed "s/__IMAGE_TAG__/$VERSION/" deploy/config.env.example > "$STAGING/config.env.example"
chmod +x "$STAGING/install.sh" "$STAGING/opsctl.sh"
chmod 644 "$STAGING/lib.sh"

# 컴포즈를 쓰는 사이트를 위해 함께 넣는다. install.sh 는 컴포즈 없이도 동작한다.
sed "s/__IMAGE_TAG__/$VERSION/" deploy/compose.yaml.template > "$STAGING/compose.yaml"

cat > "$STAGING/VERSION" <<EOF
$APP $VERSION
빌드 시각  $BUILD_TIME
소스 커밋  $REVISION
미커밋 변경 $SOURCE_DIRTY
이미지     $IMAGE:$VERSION (linux/amd64)
EOF
echo "  [OK] $(find "$STAGING" -type f | wc -l)개 파일"

# --- 묶기 -----------------------------------------------------------------
echo
echo "[5/5] 압축"
BUNDLE="$ROOT/dist/$APP-$VERSION-offline.tar.gz"
rm -f "$BUNDLE"
tar -czf "$BUNDLE" -C "$ROOT/dist" "$APP-$VERSION"
( cd "$ROOT/dist" && sha256sum "$(basename "$BUNDLE")" > "$(basename "$BUNDLE").sha256" )

echo
echo "=============================================="
echo "완성"
echo
echo "  $BUNDLE"
echo "  $(du -h "$BUNDLE" | awk '{print $1}')"
echo "  $(cut -c1-16 < "$BUNDLE.sha256")..."
echo
echo "  폐쇄망 서버에서:"
echo "    tar -xzf $(basename "$BUNDLE")"
echo "    cd $APP-$VERSION"
echo "    ./install.sh"
echo
