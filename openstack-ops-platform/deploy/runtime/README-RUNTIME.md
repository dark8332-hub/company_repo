# 컨테이너 런타임 설치 안내 (폐쇄망)

대상 서버에 `docker`·`podman`·`nerdctl` 이 **하나도 없을 때** 먼저 설치하는 번들입니다.
런타임이 이미 있다면 이 번들은 필요 없습니다. 플랫폼 번들의 `./install.sh` 만 실행하세요.

들어 있는 것은 `containerd` + `runc` + `CNI 플러그인` + `nerdctl` 입니다. 배포판 패키지(rpm·deb)가
아니라 정적 바이너리 묶음이라 RHEL·Rocky·Ubuntu 어디서든 같은 방식으로 설치됩니다. 설치 중
외부에서 내려받는 것이 없습니다.

---

## 플랫폼 번들과 다른 점

플랫폼 번들은 서버를 고치지 않습니다. **이 번들은 고칩니다.** 런타임 설치는 본래 시스템 작업이라
피할 수 없습니다. 대신 무엇을 고쳤는지 `installed-manifest.txt` 에 한 줄씩 남기고,
`./uninstall-runtime.sh` 가 그 목록만 되돌립니다.

### 서버에 생기는 변화

| 변화 | 위치 | 되돌리기 |
|---|---|---|
| 바이너리 | `/usr/local/bin/` (containerd, runc, nerdctl, buildkit 등) | `uninstall-runtime.sh` |
| CNI 플러그인 | `/usr/local/libexec/cni/` | `uninstall-runtime.sh` |
| systemd 유닛 | `/etc/systemd/system/containerd.service` | `uninstall-runtime.sh` |
| CNI 네트워크 설정 | `/etc/cni/net.d/nerdctl-bridge.conflist` | `uninstall-runtime.sh` |
| `net.ipv4.ip_forward` | 0 이었다면 1 로 변경 | `uninstall-runtime.sh` 가 원래 값으로 |
| `net.bridge.bridge-nf-call-iptables` | 0 이었다면 1 로 변경 | `uninstall-runtime.sh` 가 원래 값으로 |
| 재부팅 유지 설정 | `/etc/sysctl.d/99-openstack-ops-runtime.conf`, `/etc/modules-load.d/openstack-ops-runtime.conf` | `uninstall-runtime.sh` |
| containerd 서비스 | enable + start | `uninstall-runtime.sh` |
| containerd 데이터 | `/var/lib/containerd/`, `/run/containerd/` | 아래 「완전 삭제」 참고 |

`--prefix` 로 설치 위치를 바꿀 수 있습니다. 사이트 정책상 `/usr/local` 을 쓸 수 없을 때만 쓰세요.

커널 모듈(`overlay`·`br_netfilter`)과 파라미터를 재부팅 뒤까지 유지하는 파일을 넣습니다. 지금 값만
바꾸면 다음 부팅에 되돌아가고, 그러면 **컨테이너는 뜨는데 점검만 안 되는** 상태가 됩니다. 원인을
찾기 어려운 종류의 고장이라 기본으로 넣습니다. 사이트 정책상 안 된다면 `--no-persist` 를 쓰세요.

---

## 사전 확인

| 항목 | 조건 | 확인 |
|---|---|---|
| 아키텍처 | x86_64 | `uname -m` |
| 권한 | root 또는 sudo | |
| init | systemd | `systemctl --version` |
| 커널 | overlayfs | `grep overlay /proc/filesystems` |
| 방화벽 도구 | iptables (브리지를 쓸 때 **필수**) | `command -v iptables` |
| 기존 런타임 | **없어야 함** | `command -v docker podman nerdctl containerd` |
| 브리지 대역 | `10.4.0.0/24` 가 사내망과 겹치지 않아야 함 | `ip route` |

마지막 항목이 실무에서 가장 자주 걸립니다. 사이트 관리망이 `10.0.0.0/8` 이면 기본 대역과
겹칩니다. 설치 스크립트가 이것을 검사해 겹치면 **중단합니다**. 아래 「브리지 대역이 겹칠 때」를 보세요.

---

## 설치

```sh
tar -xzf openstack-ops-runtime-<버전>-offline.tar.gz
cd openstack-ops-runtime-<버전>
sudo ./install-runtime.sh
```

설치 후 `PATH` 에 `/usr/local/bin` 이 없으면 다음을 실행하거나 새로 로그인합니다.

```sh
export PATH=$PATH:/usr/local/bin
```

이어서 플랫폼 번들을 설치합니다.

```sh
cd ../openstack-ops-platform-<버전>
./install.sh
```

> `sudo ./install.sh` 로 실행할 때는 `sudo` 가 `PATH` 를 좁혀 `/usr/local/bin` 을 못 볼 수 있습니다.
> `sudo env "PATH=$PATH" ./install.sh` 또는 `sudo OPS_RUNTIME=/usr/local/bin/nerdctl ./install.sh` 를 쓰세요.

---

## 옵션

| 옵션 | 용도 |
|---|---|
| `--cni-subnet CIDR` | 컨테이너 브리지 대역 지정 (기본 `10.4.0.0/24`) |
| `--no-bridge` | 브리지를 만들지 않음. 플랫폼을 `USE_HOST_NETWORK=yes` 로 쓸 때 |
| `--prefix DIR` | 설치 위치 (기본 `/usr/local`) |
| `--no-persist` | 커널 모듈·파라미터를 재부팅 뒤까지 유지하지 않음 |
| `--force` | 기존 런타임이 있어도, 파일을 덮어써야 해도, iptables 가 없어도 진행 |

`--force` 는 이미 컨테이너가 돌고 있는 서버에서 그 컨테이너를 멈출 수 있습니다.
기본 동작(중단)이 안전하므로, 왜 중단됐는지 확인한 뒤에만 쓰세요.

### 브리지 대역이 겹칠 때

두 가지 방법이 있습니다.

```sh
# 1) 겹치지 않는 대역으로 바꾼다
sudo ./install-runtime.sh --cni-subnet 172.31.240.0/24

# 2) 브리지를 아예 쓰지 않는다 (플랫폼은 host 네트워크로 실행)
sudo ./install-runtime.sh --no-bridge
#   → 플랫폼 번들 config.env 에 USE_HOST_NETWORK=yes
```

점검 대상 노드가 사설망 곳곳에 흩어져 있는 환경에서는 2번이 단순합니다.
브리지·NAT·포워딩이 전부 빠지므로 경로 문제가 생길 여지가 없습니다.
대신 포트가 8090 고정이고 서버 네트워크를 그대로 쓰게 됩니다.

---

## 확인

```sh
nerdctl info
nerdctl --namespace openstack-ops ps
systemctl status containerd
```

---

## 제거

플랫폼을 먼저 지우고 런타임을 지웁니다. 순서를 바꾸면 플랫폼 컨테이너를 지울 수단이 없어집니다.

```sh
cd <플랫폼 번들> && ./opsctl.sh remove --all
cd <런타임 번들> && sudo ./uninstall-runtime.sh
```

`uninstall-runtime.sh` 는 `installed-manifest.txt` 에 적힌 것만 지웁니다. 돌고 있는 컨테이너가
있으면 중단합니다(`--force` 로 우회).

### 완전 삭제

containerd 가 만든 데이터 디렉터리는 설치 기록에 없으므로 남습니다. 이 서버에서 컨테이너를
완전히 걷어낼 때만 지우세요.

```sh
sudo rm -rf /var/lib/containerd /var/lib/nerdctl /var/lib/cni /run/containerd /etc/cni/net.d
sudo ip link delete nerdctl0 2>/dev/null || true
```

---

## 문제 해결

**`이 서버에는 이미 컨테이너 런타임이 있습니다`**
정상적인 보호 동작입니다. 기존 런타임을 그대로 쓰면 되므로 이 번들을 실행할 필요가 없습니다.
플랫폼 번들의 `./install.sh` 만 실행하세요.

**`iptables 가 없습니다`**
브리지 네트워크의 포트 매핑(DNAT)과 NAT 이 iptables 로 이뤄지므로, 없으면 화면이 열리지 않고
점검도 노드에 닿지 못합니다. 반쪽만 동작하는 상태로 두지 않으려고 설치를 중단합니다.
`--no-bridge` 로 설치하고 플랫폼을 `USE_HOST_NETWORK=yes` 로 쓰는 것이 가장 간단합니다.

**컨테이너는 떴는데 화면이 열리지 않는다 / 재부팅 뒤에 점검만 실패한다**
`br_netfilter` 와 `net.bridge.bridge-nf-call-iptables`, `net.ipv4.ip_forward` 를 확인하세요.
설치 시 넣은 `/etc/sysctl.d/99-openstack-ops-runtime.conf` 와
`/etc/modules-load.d/openstack-ops-runtime.conf` 가 그대로 있는지 봅니다(`--no-persist` 로
설치했다면 없습니다). 노드까지 어느 층에서 막혔는지는 플랫폼 번들의
`./opsctl.sh netcheck <노드주소>` 가 알려 줍니다.

**`containerd 가 응답하지 않습니다`**
`systemctl status containerd` 와 `journalctl -u containerd -n 50` 을 확인합니다.
대개 overlayfs 모듈이 없거나 cgroup 설정 문제입니다.

**`컨테이너 브리지 대역이 기존 경로와 겹칩니다`**
위 「브리지 대역이 겹칠 때」를 보세요.

**`nerdctl: command not found` (설치는 됐는데)**
`PATH` 문제입니다. `export PATH=$PATH:/usr/local/bin`. `sudo` 로 실행할 때는
`sudo env "PATH=$PATH" ...` 를 쓰거나 절대 경로로 부르세요.

**SELinux 가 enforcing 인 서버**
바이너리를 `/usr/local/bin` 에 두는 것은 문제되지 않습니다. 플랫폼 번들이 바인드 마운트에
`:Z` 를 자동으로 붙입니다.
