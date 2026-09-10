# OpenStack 운영 지원 플랫폼 — 폐쇄망 설치 안내

인터넷이 없는 서버에 이 플랫폼을 올리는 절차입니다. 컨테이너 이미지와 실행에 필요한 것이
모두 이 번들 안에 들어 있어, 설치 중 외부에서 내려받는 것이 없습니다.

---

## 이 번들이 서버에 남기는 것

| 남기는 것 | 위치 |
|---|---|
| 컨테이너 1개 | 런타임이 관리 (`openstack-ops-platform`) |
| 컨테이너 이미지 1개 | 런타임 이미지 저장소 (약 273MB) |
| 데이터 | 이 디렉터리 아래 `data/` |

**그 외에는 아무것도 건드리지 않습니다.** 패키지를 설치하지 않고, 시스템 설정(`/etc`, 방화벽,
`sysctl`, SELinux)을 고치지 않으며, 번들 디렉터리 밖에 파일을 쓰지 않습니다. `systemd` 유닛만
선택 사항으로 따로 안내합니다.

### 서버에 실제로 생기는 변화

| 변화 | 설명 | 되돌리기 |
|---|---|---|
| 컨테이너 1개 | `--restart unless-stopped`. `docker`는 재부팅 후 자동 기동합니다 | `./opsctl.sh remove` |
| 이미지 1개 | 런타임 이미지 저장소 (약 273MB) | `./opsctl.sh remove` |
| 포트 1개 | `HOST_PORT`(기본 8090) LISTEN. docker는 이때 NAT 규칙을 자동으로 넣습니다 | 컨테이너 제거 시 함께 사라짐 |
| `data/` | 번들 안. 컨테이너가 root로 쓰므로 파일 소유자는 root입니다 | `./opsctl.sh remove --all` |
| systemd 유닛 1개 | **선택.** `sudo ./opsctl.sh install-service` 를 실행했을 때만 생깁니다 | `sudo ./opsctl.sh uninstall-service` |

`nerdctl`을 쓰는 서버에서는 전용 namespace(`openstack-ops`)를 쓰므로 k8s 노드의 기존
이미지·컨테이너와 섞이지 않습니다. `docker`·`podman`은 namespace 개념이 없어 이미지가
호스트의 공용 저장소에 들어갑니다(이름 `okestro/openstack-ops-platform`).

### 이미 돌고 있는 서비스를 건드리지 않기 위한 확인

- **포트**: 설치 전과 컨테이너 기동 직전 두 번 확인합니다. 호스트 프로세스(`ss`)와 **다른
  컨테이너가 게시한 포트**(런타임에 조회) 양쪽을 봅니다. `nerdctl`·CNI는 포트를 iptables DNAT로
  매핑해 LISTEN 소켓이 없으므로 `ss`만으로는 보이지 않기 때문입니다. 이미 쓰이고 있으면
  **설치를 중단합니다**(상대 서비스는 건드리지 않습니다). `USE_HOST_NETWORK=yes`에서는
  `HOST_PORT`가 무시되고 8090을 쓰므로 8090을 기준으로 확인합니다.
- **컨테이너 이름**: 같은 이름의 컨테이너가 있으면 이미지 저장소를 정확히 비교하고 관리 라벨을 확인해 **이 플랫폼의 것이 아니거나 식별에 실패하면
  지우지 않고 중단합니다**. 재설치 시에만 기존 컨테이너를 교체합니다.
- **기동 확인**: 컨테이너 *안에서* 확인합니다. 호스트 포트로만 확인하면 같은 포트를 쓰는 다른
  서비스가 대신 응답해 기동 실패를 성공으로 오판합니다.
- **실패 시**: 컨테이너를 정지시킵니다. `--restart unless-stopped` 때문에 재시작 루프가
  서버에 남지 않도록 합니다.

되돌리기: `./opsctl.sh remove --all` 후 이 디렉터리를 삭제하면 흔적이 남지 않습니다.
`data/`는 컨테이너가 root로 쓰므로, 설치를 root가 아닌 계정으로 했다면 삭제에 `sudo`가 필요합니다.

---

## 사전 확인

| 항목 | 조건 |
|---|---|
| 아키텍처 | x86_64 |
| 컨테이너 런타임 | `docker`, `podman`, `nerdctl` 중 하나 (없으면 런타임 번들 먼저, 아래 참고) |
| 여유 디스크 | 1GB 이상 (이미지 273MB + 점검 이력) |
| 포트 | 8090 (`config.env`에서 변경 가능) |
| 네트워크 | 이 서버에서 점검 대상 OpenStack 노드로 **SSH 접속이 되어야** 합니다 |

런타임 실행 권한이 필요합니다. `root`가 아니면 `sudo`로 실행하거나 계정을 `docker` 그룹에 넣으세요.

런타임이 하나도 없다면 함께 반입한 런타임 번들(`openstack-ops-runtime-<버전>-offline.tar.gz`)을
먼저 설치합니다. containerd + runc + CNI + nerdctl 정적 바이너리를 넣고, 무엇을 바꿨는지
기록해 되돌릴 수 있게 합니다. 절차는 그 번들 안의 `README-RUNTIME.md` 에 있습니다.

```sh
tar -xzf openstack-ops-runtime-<버전>-offline.tar.gz
cd openstack-ops-runtime-<버전> && sudo ./install-runtime.sh
```

---

## 설치

```sh
tar -xzf openstack-ops-platform-<버전>-offline.tar.gz
cd openstack-ops-platform-<버전>
./install.sh
```

`install.sh`는 런타임 감지 → 이미지 무결성 확인 → 적재 → 기동 → 응답 확인까지 하고,
마지막에 접속 주소와 초기 계정을 출력합니다.

포트나 시간대를 먼저 바꾸려면 설치 전에 `config.env.example`을 `config.env`로 복사해 고치세요.

### 첫 접속

1. 안내된 주소로 접속 → `admin` / `Okestro2018@` 로 로그인 (첫 로그인에서 비밀번호 변경을 요구합니다)
2. **[공급자 연결]** 에서 대표 VIP와 SSH 계정으로 공급자를 등록합니다
3. **[일일점검]** 에서 클러스터 노드를 탐색한 뒤 점검을 실행합니다

> **공급자는 이관되지 않습니다.** 공급자 정보·점검 이력·알림은 모두 `data/` 안의 DB에 있고
> 이미지에는 들어 있지 않습니다. 새 사이트에서는 항상 새로 등록하는 것이 정상입니다.
> 이는 의도된 동작입니다. 공급자 DB에는 그 사이트의 SSH·MySQL 비밀번호가 암호화되어 들어 있어,
> 다른 사이트로 옮겨서는 안 되는 자료입니다.

### 공급자 등록에 필요한 정보

| 항목 | 비고 |
|---|---|
| 대표 VIP 주소, SSH 포트 | |
| SSH 계정 | `root` 또는 sudo 권한이 있는 운영 계정 |
| 인증 수단 | 개인키 또는 비밀번호 |
| sudo 방식 | sudo 비밀번호 인증 |
| MySQL 계정 | Middleware 점검용 (선택) |
| Prometheus 주소 | 모니터링 연동용 (선택) |

---

## 운영

```sh
./opsctl.sh status          # 상태와 응답 확인
./opsctl.sh logs            # 최근 100줄
./opsctl.sh logs -f         # 실시간
./opsctl.sh restart         # config.env 를 고친 뒤 반영
./opsctl.sh stop            # 정지 (데이터는 남습니다)
./opsctl.sh backup          # data 디렉터리를 tar.gz 로
./opsctl.sh restore <파일>  # 백업으로 되돌리기
./opsctl.sh remove          # 컨테이너·이미지 제거 (data 는 남김)
./opsctl.sh remove --all    # data 까지 삭제

./opsctl.sh netcheck <노드IP> [포트]   # 컨테이너에서 노드까지 닿는지 단계별 확인

sudo ./opsctl.sh install-service     # 재부팅 후 자동 기동 (systemd 유닛 설치)
sudo ./opsctl.sh uninstall-service   # 그 유닛 제거
```

### 백업

`data/`에는 두 가지가 들어 있고 **둘 다 있어야** 복원됩니다.

- `providers.db` — 공급자, 점검 이력, 알림, 작업 이력, 감사 로그
- `.master_key` — SSH·MySQL 비밀번호를 푸는 Fernet 키 (첫 공급자 등록 시 생성)

`./opsctl.sh backup`은 컨테이너를 잠시 멈춰 SQLite 일관성을 확보한 뒤 둘을 함께 묶습니다.
**백업 파일에는 마스터 키가 들어 있으므로 접근 통제된 곳에 보관하세요.**

### 백업 실패·복원 검증

- 백업은 권한 600의 임시 파일에 생성한 뒤 성공했을 때만 최종 파일로 바꿉니다. 실패·중단 시 부분 파일을 지우고, 원래 실행 중이던 서비스는 다시 기동하고 응답을 확인합니다. 원래 정지 상태였다면 정지 상태를 유지합니다.
- 복원은 서비스 정지 전에 전체 경로와 파일 유형을 검사합니다. `data/` 밖의 항목, 경로 이동(`..`), 중복 경로, 심볼릭 링크·하드 링크·특수 파일은 거부합니다. 유효한 일반 파일과 디렉터리만 임시 위치에 풀고 교체합니다.
- 호스트에 Python이 없으면 이미 반입한 앱 이미지의 Python을 네트워크 없이 실행해 검증합니다. 추가 패키지 다운로드는 없습니다.
- 교체 전 데이터는 `data.before-restore.<임의값>/`에 남습니다. 복원 후 기동에 실패하면 이 경로와 로그를 확인해 이전 데이터로 되돌릴 수 있습니다.
- 설치·재시작·복원은 포트 충돌을 확인하며, 기존 컨테이너가 있으면 삭제 전에 소유를 확인합니다. 소유를 판단할 수 없으면 중단합니다. 기존 라벨 없는 번들은 정확한 이미지 저장소 이름으로 식별합니다.

### 재부팅 후 자동 기동

`docker`는 `--restart unless-stopped` 로 자동 기동됩니다. `podman`과 `nerdctl`은 그렇지 않으므로
아래 명령으로 `systemd` 유닛을 설치하세요. 이것이 번들 디렉터리 밖에 파일을 만드는 유일한 선택 사항입니다.

```sh
sudo ./opsctl.sh install-service     # 유닛 설치 + 부팅 시 자동 기동 등록 + 기동
sudo ./opsctl.sh uninstall-service   # 유닛 제거 (컨테이너는 그대로 둡니다)
```

`install-service`가 하는 일은 이렇습니다.

- `systemd/openstack-ops-platform.service.template`의 `__BUNDLE_DIR__`을 이 번들의 절대경로로 바꿉니다.
- 바뀐 결과를 검사합니다. 자리표시자가 남았거나 `WorkingDirectory`·`ExecStart`가 절대경로가 아니면
  **설치하지 않고 중단합니다**. systemd는 이런 유닛을 `bad unit file setting`으로만 알려 주기 때문에,
  파일을 놓기 전에 잡는 편이 낫습니다.
- 같은 이름의 유닛이 이미 있는데 이 번들이 만든 것이 아니면 **덮어쓰지 않고 중단합니다**.
- 놓은 유닛 경로를 `installed-service.txt`에 적고, `uninstall-service`는 **거기 적힌 것만** 지웁니다.
- 유닛 이름은 `config.env`의 `CONTAINER_NAME`을 따릅니다(기본 `openstack-ops-platform`).
  한 서버에 두 벌을 설치한다면 이름을 다르게 두세요.

`uninstall-service`는 `disable`만 하고 컨테이너는 내리지 않습니다. 자동 기동만 끄려던 것이지
서비스를 멈추려던 것이 아니기 때문입니다. 함께 내리려면 `./opsctl.sh stop`을 쓰세요.

손으로 만들어야 한다면 자리표시자는 밑줄 두 개를 포함한 `__BUNDLE_DIR__` 전체입니다.
`BUNDLE_DIR`만 바꾸면 `__/경로__`가 남아 systemd가 유닛을 거부합니다.

```sh
sed "s#__BUNDLE_DIR__#$(pwd)#" systemd/openstack-ops-platform.service.template \
  | sudo tee /etc/systemd/system/openstack-ops-platform.service
sudo systemctl daemon-reload
sudo systemctl enable --now openstack-ops-platform
```

---

## 설정 (`config.env`)

고친 뒤에는 `./opsctl.sh restart`로 반영합니다. 환경 변수는 컨테이너 생성 시점에 고정되므로
`stop`/`start`가 아니라 `restart`여야 합니다.

| 키 | 기본값 | 설명 |
|---|---|---|
| `HOST_PORT` | `8090` | 웹 화면 포트 |
| `BIND_ADDRESS` | `0.0.0.0` | `127.0.0.1`로 두면 이 서버에서만 접속 |
| `USE_HOST_NETWORK` | `no` | 브리지 네트워크로 점검 대상 노드에 닿지 않을 때 `yes` |
| `TIMEZONE` | `Asia/Seoul` | 예약 점검 시각과 로그 시각의 기준 |
| `ADMIN_USERNAME` | `admin` | |
| `ADMIN_PASSWORD` | (빈 값) | 비우면 `Okestro2018@` + 첫 로그인 변경 강제 |
| `SESSION_TTL_HOURS` | `8` | 로그인 세션 유지 시간 |

---

## 문제 해결

**`docker, podman, nerdctl 중 어느 것도 없습니다`**
런타임이 다른 이름이거나 `PATH`에 없습니다. `OPS_RUNTIME=/usr/bin/podman ./install.sh` 처럼 지정하세요.
정말로 하나도 없다면 런타임 번들을 먼저 설치합니다(위 「사전 확인」). 런타임 번들로 설치한 뒤에는
`/usr/local/bin` 이 `PATH` 에 있어야 하며, `sudo` 로 실행할 때는 `sudo env "PATH=$PATH" ./install.sh`
또는 `sudo OPS_RUNTIME=/usr/local/bin/nerdctl ./install.sh` 를 씁니다.

**`... 이(가) 응답하지 않습니다`**
데몬이 죽었거나 소켓 권한이 없습니다. `systemctl status docker` 확인 후 `sudo`로 실행하세요.

**포트가 이미 사용 중**
`config.env`의 `HOST_PORT`를 바꾸고 다시 실행하세요.

**공급자 등록은 되는데 노드 점검이 실패**
어느 층에서 막혔는지부터 봅니다. 이미지는 `python:3.12-slim` 이라 `nc`·`ping`·`ssh`·`curl` 이
들어 있지 않습니다. 컨테이너에 들어가 확인하려 하지 말고 다음 명령을 쓰세요.

```sh
./opsctl.sh netcheck <노드IP>
```

컨테이너 안과 이 서버 양쪽에서 이름 해석 → 경로 → TCP 22 → SSH 배너를 차례로 확인하고,
결과에 따라 다음 중 하나를 알려 줍니다.

| 결과 | 뜻 | 조치 |
|---|---|---|
| 둘 다 성공 | 네트워크는 정상 | 계정·키·호스트 키 승인·sudo 권한 문제입니다. **[공급자 연결] → 연결 진단** |
| 컨테이너만 실패 | 브리지가 사설망에 닿지 못함 | `config.env` 에 `USE_HOST_NETWORK=yes` 후 `./opsctl.sh restart` |
| 이름 해석 실패 | 컨테이너는 호스트 `/etc/hosts` 를 물려받지 않음 | **[공급자 연결] → 노드 인벤토리**에 노드 IP 직접 입력, 또는 노드 탐색 재실행 |
| 둘 다 실패 | 이 서버에서 노드로 가는 경로가 없음 | 라우팅·방화벽·노드 `sshd` 를 확인합니다. 컨테이너 문제가 아닙니다 |
| 열렸는데 SSH 아님 | 다른 서비스이거나 포트가 다름 | 노드의 SSH 포트를 확인합니다 |

`USE_HOST_NETWORK=yes` 로 바꾸면 `HOST_PORT` 가 무시되고 8090 이 쓰입니다. 8090 을 다른
서비스가 쓰고 있다면 그 서비스를 옮기거나 브리지 경로를 고쳐야 합니다.

**호스트명 해석 실패 (`gaierror`)**
탐색 단계에서 Controller가 알려준 IP를 저장해 쓰므로 보통 자동 해결됩니다.
그래도 실패하면 **[공급자 연결] → 노드 인벤토리**에서 노드 IP를 직접 입력하세요.

**화면 글꼴이 깨져 보임**
Inter와 Noto Sans KR은 이미지에 들어 있어 인터넷 없이도 나옵니다.
브라우저가 이전 버전을 캐시한 경우이므로 강력 새로고침(Ctrl+Shift+R)하세요.

**로그인 비밀번호를 잊음**
`config.env`에 `ADMIN_PASSWORD=<새 비밀번호>`, `ADMIN_PASSWORD_RESET=1` 을 넣고 `./opsctl.sh restart`.
로그인한 뒤 두 값을 다시 비우고 `restart` 하세요.

---

## 업그레이드

새 번들을 별도 디렉터리에 풀고, 기존 `data/`를 옮긴 뒤 설치합니다.

```sh
cd <기존 디렉터리> && ./opsctl.sh backup && ./opsctl.sh stop
cd <새 디렉터리>
cp -a ../<기존 디렉터리>/data ./data
cp ../<기존 디렉터리>/config.env ./config.env   # IMAGE_TAG 는 새 값으로 고칩니다
./install.sh
```

기존 디렉터리는 새 버전이 정상 동작하는 것을 확인한 뒤에 지우세요.
