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

**그 외에는 아무것도 건드리지 않습니다.** 패키지를 설치하지 않고, 시스템 설정을 고치지 않으며,
번들 디렉터리 밖에 파일을 쓰지 않습니다. `systemd` 유닛만 선택 사항으로 따로 안내합니다.

되돌리기: `./opsctl.sh remove --all` 후 이 디렉터리를 삭제하면 흔적이 남지 않습니다.

---

## 사전 확인

| 항목 | 조건 |
|---|---|
| 아키텍처 | x86_64 |
| 컨테이너 런타임 | `docker`, `podman`, `nerdctl` 중 하나 |
| 여유 디스크 | 1GB 이상 (이미지 273MB + 점검 이력) |
| 포트 | 8090 (`config.env`에서 변경 가능) |
| 네트워크 | 이 서버에서 점검 대상 OpenStack 노드로 **SSH 접속이 되어야** 합니다 |

런타임 실행 권한이 필요합니다. `root`가 아니면 `sudo`로 실행하거나 계정을 `docker` 그룹에 넣으세요.

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
| sudo 방식 | NOPASSWD 또는 sudo 비밀번호 |
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
```

### 백업

`data/`에는 두 가지가 들어 있고 **둘 다 있어야** 복원됩니다.

- `providers.db` — 공급자, 점검 이력, 알림, 작업 이력, 감사 로그
- `.master_key` — SSH·MySQL 비밀번호를 푸는 Fernet 키 (첫 공급자 등록 시 생성)

`./opsctl.sh backup`은 컨테이너를 잠시 멈춰 SQLite 일관성을 확보한 뒤 둘을 함께 묶습니다.
**백업 파일에는 마스터 키가 들어 있으므로 접근 통제된 곳에 보관하세요.**

### 재부팅 후 자동 기동

`docker`는 `--restart unless-stopped` 로 자동 기동됩니다. `podman`과 `nerdctl`은 그렇지 않으므로
아래 유닛을 설치하세요. 이것이 번들 디렉터리 밖에 파일을 만드는 유일한 선택 사항입니다.

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

**`... 이(가) 응답하지 않습니다`**
데몬이 죽었거나 소켓 권한이 없습니다. `systemctl status docker` 확인 후 `sudo`로 실행하세요.

**포트가 이미 사용 중**
`config.env`의 `HOST_PORT`를 바꾸고 다시 실행하세요.

**공급자 등록은 되는데 노드 점검이 실패**
컨테이너에서 점검 대상 노드로 SSH가 나가지 못하는 경우입니다.
`./opsctl.sh shell` 로 들어가 `nc -z <노드IP> 22` 로 확인하고, 막혀 있으면
`config.env`의 `USE_HOST_NETWORK=yes` 로 바꾼 뒤 `./opsctl.sh restart` 하세요.

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
