#!/bin/bash
set -e

NAME="okestro-os-ansible"
IMAGE="openstack-ansible:v1.5"

echo "[1] stop/remove container"
nerdctl rm -f "$NAME" 2>/dev/null || true

echo "[2] remove image (and dangling <none>)"
nerdctl rmi -f "$IMAGE" 2>/dev/null || true
nerdctl images --format '{{.Repository}}:{{.Tag}} {{.ID}}' \
  | awk '$1=="<none>:<none>" {print $2}' \
  | sort -u \
  | xargs -r nerdctl rmi -f || true

echo "[3] stop/disable services"
systemctl stop buildkit.service buildkit.socket containerd.service 2>/dev/null || true
systemctl disable buildkit.service buildkit.socket containerd.service 2>/dev/null || true

echo "[4] remove systemd units and reload"
rm -f /etc/systemd/system/containerd.service
rm -f /etc/systemd/system/buildkit.service
rm -f /etc/systemd/system/buildkit.socket
systemctl daemon-reload 2>/dev/null || true
systemctl reset-failed 2>/dev/null || true

echo "[5] remove configs"
rm -rf /etc/containerd /etc/nerdctl /etc/buildkit

echo "[6] remove runtime data"
rm -rf /var/lib/containerd /run/containerd
rm -rf /var/lib/buildkit /run/buildkit
rm -rf /var/lib/nerdctl
rm -rf /opt/containerd

echo "[7] remove cni plugins"
rm -rf /opt/cni/bin/* 2>/dev/null || true

echo "[8] remove binaries (tarball installs)"
rm -f /usr/local/bin/nerdctl
rm -f /usr/local/bin/runc
rm -f /usr/local/bin/buildctl /usr/local/bin/buildkitd
rm -f /usr/local/bin/containerd /usr/local/bin/ctr
rm -f /usr/local/bin/containerd-shim /usr/local/bin/containerd-shim-runc-v2
rm -f /usr/local/bin/containerd-stress
rm -f /usr/local/bin/containerd-rootless.sh /usr/local/bin/containerd-rootless-setuptool.sh
rm -f /usr/local/bin/buildkit-qemu-* 2>/dev/null || true
rm -f /usr/local/bin/buildkit-runc 2>/dev/null || true

echo "[9] remove all files under /root/.ssh"
rm -rf /root/.ssh/* /root/.ssh/.[!.]* /root/.ssh/..?* 2>/dev/null || true


echo "[DONE] purge complete"

