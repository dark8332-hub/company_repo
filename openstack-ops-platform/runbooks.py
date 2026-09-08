"""Built-in 조치 가이드(런북) for the daily-inspection items.

Each entry is short Markdown: 확인 순서 → 원인 후보 → 조치 → 확인. Sites override any entry through the
per-provider setting `runbooks` ({item_key: markdown}); the effective text is served by GET /api/runbooks/{item_key}.
"""

_LOG_RUNBOOK = """## {service} 로그 오류
1. 상세 결과의 **신규 오류**와 **지속 오류**를 구분합니다. 지속 오류는 전전날에도 있었으므로 장기 원인일 가능성이 큽니다.
2. 반복 메시지는 첫 발생 시각과 노드를 확인하고, 같은 시각의 다른 서비스 로그(RabbitMQ, MySQL, Keystone)를 함께 봅니다.
3. `journalctl -u {unit} --since yesterday` 또는 `/var/log/{path}/` 원문에서 Traceback 전체를 확인합니다.
4. 벤더가 무해하다고 확인한 메시지는 **로그 오류 제외 패턴**에 사유와 함께 등록해 다음 점검부터 걸러냅니다.
5. 조치 후 해당 항목만 재점검해 오류 건수가 줄었는지 확인합니다.
"""

RUNBOOKS: dict[str, str] = {
    "pcs": """## PCS 클러스터
1. 활성 Controller에서 `pcs status`로 Offline 노드와 Stopped/Failed 리소스를 확인합니다.
2. `pcs status --full`에서 실패 횟수(fail-count)와 마지막 실패 사유를 봅니다.
3. 노드가 Offline이면 해당 노드의 `systemctl status pacemaker corosync`와 관리망 통신(ping, `corosync-cfgtool -s`)을 확인합니다.
4. 리소스 실패는 원인(서비스 자체 장애, 의존 리소스)을 해결한 뒤 `pcs resource cleanup <리소스>`로 실패 기록을 정리합니다.
5. 정리 후 `pcs status`에서 모든 리소스가 Started인지 확인하고 항목을 재점검합니다.
""",
    "vip": """## VIP 통신
1. `pcs status | grep vip`로 VIP 리소스가 어느 Controller에서 실행 중인지 확인합니다.
2. 해당 Controller에서 `ip addr`로 VIP가 인터페이스에 할당되어 있는지, `ss -ltnp | grep 15000`으로 HAProxy가 수신 중인지 봅니다.
3. 다른 Controller와 배포 서버에서 `arp -n <VIP>`가 INCOMPLETE/FAILED이면 스위치 ARP 학습 또는 가상 환경의 allowed-address-pairs·포트 보안 설정을 확인합니다.
4. VIP가 이동한 직후라면 `arping -U -I <인터페이스> <VIP>`로 Gratuitous ARP를 보내 상위 스위치를 갱신합니다.
5. 복구 후 배포 서버에서 `ping <VIP>`와 Keystone `/v3/` 응답을 확인하고 OpenStack 서비스 항목을 재점검합니다.
""",
    "rabbitmq": """## RabbitMQ 클러스터
1. `rabbitmqctl cluster_status`에서 running_nodes에 빠진 노드와 network partition 여부를 확인합니다.
2. 파티션이 있으면 소수 쪽 노드에서 `rabbitmqctl stop_app && rabbitmqctl start_app`으로 재합류합니다.
3. 노드가 내려가 있으면 `systemctl status rabbitmq-server`와 `/var/log/rabbitmq/`의 오류(디스크 알람, 메모리 알람, Erlang cookie 불일치)를 확인합니다.
4. `rabbitmqctl list_queues name messages consumers | sort -k2 -n | tail`로 적체된 큐가 있는지 확인하고 소비자 서비스(nova-conductor 등)를 점검합니다.
5. 복구 후 `rabbitmqctl cluster_status`와 Nova·Neutron 서비스 항목을 재점검합니다.
""",
    "mysql": """## MySQL(Galera) 클러스터
1. `mysql -e "SHOW STATUS LIKE 'wsrep_%'"`에서 `wsrep_cluster_size`, `wsrep_cluster_status`(Primary), `wsrep_local_state_comment`(Synced)를 확인합니다.
2. 노드가 빠져 있으면 해당 노드의 `systemctl status mariadb`와 `/var/log/mysql/error.log`에서 SST/IST 실패 원인을 확인합니다.
3. 전체 노드가 Non-Primary이면 가장 최신 seqno 노드(`grep seqno /var/lib/mysql/grastate.dat`)에서 부트스트랩합니다.
4. 디스크 가득 참, 연결 수 초과(`max_connections`)는 항목 상세의 오류 문구로 구분합니다.
5. 복구 후 `wsrep_cluster_size`가 Controller 수와 같은지 확인하고 항목을 재점검합니다.
""",
    "mysql_host_blocked_errors": """## MySQL Host Blocked Errors
1. `SELECT IP, COUNT_HOST_BLOCKED_ERRORS FROM performance_schema.host_cache WHERE COUNT_HOST_BLOCKED_ERRORS>0;`로 차단된 호스트를 확인합니다.
2. 해당 호스트의 서비스가 잘못된 인증정보로 반복 접속하고 있지 않은지(설정 파일의 DB 비밀번호) 확인합니다.
3. 원인을 고친 뒤 `FLUSH HOSTS;`로 host_cache를 비웁니다. `max_connect_errors` 값이 지나치게 작으면 조정합니다.
4. 재점검에서 값이 0으로 돌아오는지 확인합니다.
""",
    "wsrep_local_cert_failures": """## WSREP Local Cert Failures
1. 값은 누적치이므로 증가 추세인지 여러 점검 결과로 비교합니다.
2. 같은 행을 여러 Controller가 동시에 갱신하는 워크로드(예: Neutron 에이전트 하트비트, Nova 서비스 갱신)가 원인인 경우가 많습니다.
3. HAProxy가 쓰기를 한 Controller로만 보내는지(`backend mysql` 설정의 backup 옵션)를 확인합니다.
4. 증가가 멈추지 않으면 애플리케이션 재시도 로그를 확인하고 필요 시 서비스 재시작 후 추이를 관찰합니다.
""",
    "endpoint": """## Endpoint 목록
1. `openstack endpoint list`가 실패하면 Keystone 인증(VIP, `/root/contrabass-openrc`)이 먼저 정상인지 확인합니다.
2. 서비스별 public/internal/admin Endpoint가 모두 있는지, URL의 호스트가 현재 VIP와 같은지 확인합니다.
3. 누락된 Endpoint는 `openstack endpoint create <service> <interface> <url>`로 등록합니다.
4. 등록 후 해당 서비스 CLI(`openstack volume service list` 등)가 응답하는지 확인합니다.
""",
    "nova": """## Nova 서비스
1. `openstack compute service list`에서 State down 또는 Status disabled 서비스와 호스트를 확인합니다.
2. 해당 호스트에서 `systemctl status nova-compute`(또는 nova-conductor/scheduler)와 `/var/log/nova/`의 최근 오류를 봅니다.
3. down이지만 프로세스가 살아 있으면 RabbitMQ 연결과 시간 동기화(Chrony)를 확인합니다.
4. 의도적으로 disabled한 호스트면 사유를 확인하고, 아니면 `openstack compute service set --enable <host> nova-compute`로 활성화합니다.
5. 복구 후 서비스 목록과 VM state 항목을 재점검합니다.
""",
    "neutron": """## Neutron 에이전트
1. `openstack network agent list`에서 Alive가 XXX이거나 State DOWN인 에이전트와 호스트를 확인합니다.
2. 해당 호스트에서 에이전트 서비스(`neutron-openvswitch-agent`, `neutron-dhcp-agent`, `neutron-l3-agent`)의 상태와 로그를 확인합니다.
3. 에이전트가 살아 있는데 DOWN이면 RabbitMQ 연결, 시간 동기화, OVS 상태(`ovs-vsctl show`)를 확인합니다.
4. L3/DHCP 에이전트 장애 시 라우터·네트워크가 다른 에이전트로 이동했는지 `openstack network agent list --router <id>`로 확인합니다.
5. 복구 후 에이전트 목록과 Network state 항목을 재점검합니다.
""",
    "cinder": """## Cinder 서비스
1. `openstack volume service list`에서 State down 또는 Status disabled 서비스와 호스트, 마지막 갱신 시각을 확인합니다.
2. cinder-volume이 down이면 백엔드 저장소(NFS 마운트, Ceph, iSCSI) 접근 가능 여부와 `/var/log/cinder/cinder-volume.log`를 확인합니다.
3. NFS 백엔드는 Controller에서 `mount | grep cinder`와 `df`가 응답하는지 확인합니다(무응답이면 NFS 서버 장애).
4. 서비스 재시작 후 `openstack volume service list`가 up으로 바뀌는지 확인합니다.
5. Volume state 항목을 재점검해 error 상태 볼륨이 남아 있지 않은지 확인합니다.
""",
    "manila": """## Manila 서비스
1. `manila service-list`에서 down/disabled 서비스와 호스트를 확인합니다.
2. manila-share가 down이면 공유 백엔드 접근과 `/var/log/manila/manila-share.log`를 확인합니다.
3. 서비스 재시작 후 목록을 다시 확인하고 Share state 항목을 재점검합니다.
""",
    "octavia": """## Octavia 서비스
1. `systemctl status octavia-*`에서 실패한 서비스(api, worker, health-manager, housekeeping)를 확인합니다.
2. health-manager 장애는 Amphora 상태 갱신 실패로 이어지므로 `/var/log/octavia/`의 오류와 lb-mgmt-net 통신을 확인합니다.
3. 서비스 재시작 후 LB state와 Amphora state 항목을 재점검합니다.
""",
    "nova_compute": """## nova-compute 프로세스
1. Compute 노드에서 `systemctl status nova-compute`와 16509 포트(libvirt) 수신 여부를 확인합니다.
2. 서비스가 반복 재시작되면 `/var/log/nova/nova-compute.log`의 첫 Traceback(libvirt 연결, RabbitMQ, 설정 오류)을 확인합니다.
3. `virsh list --all`로 libvirt 자체가 응답하는지 확인합니다.
4. 복구 후 Nova 서비스 항목에서 해당 호스트가 up인지 확인합니다.
""",
    "chrony": """## Chrony 시간 동기화
1. `chronyc sources -v`와 `chronyc tracking`에서 선택된 시간원(`^*`)이 있는지, Leap status가 Normal인지 확인합니다.
2. 시간원이 없으면 `/etc/chrony/chrony.conf`의 서버 주소와 UDP 123 통신을 확인합니다.
3. 오차가 크면 `chronyc makestep`으로 즉시 보정하고 서비스를 재시작합니다.
4. 시간 불일치는 Nova·Neutron 서비스 down 오판, Galera 인증 실패의 원인이 되므로 관련 항목을 함께 재점검합니다.
""",
    "bonding": """## Bonding 인터페이스
1. `cat /proc/net/bonding/bond*`에서 MII Status가 down인 슬레이브와 현재 활성 슬레이브를 확인합니다.
2. 슬레이브 다운은 케이블·스위치 포트 문제인 경우가 많으므로 `ethtool <nic>`의 Link detected와 스위치 포트 상태를 확인합니다.
3. 802.3ad 모드는 Partner Mac Address와 LACP 협상 상태를 함께 확인합니다.
4. 복구 후 MII Status가 모두 up인지 확인하고 재점검합니다.
""",
    "mount": """## Mount 상태
1. 상세 결과에서 fstab에 있으나 마운트되지 않은 경로와 무응답 네트워크 마운트를 구분합니다.
2. NFS 무응답은 NFS 서버 상태와 네트워크를 먼저 확인합니다. `df`가 멈추면 `timeout 5 stat <경로>`로 경로별 응답을 확인합니다.
3. 미마운트 경로는 `mount -a`로 재마운트하고 오류 메시지를 확인합니다.
4. Glance 이미지·Cinder 변환 경로가 대상이면 서비스 동작(이미지 업로드, 볼륨 생성)도 함께 확인합니다.
""",
    "cpu": """## CPU 사용률
1. 상세 결과의 노드별 사용률과 `top -b -n1 | head -20`으로 상위 프로세스를 확인합니다.
2. Compute 노드는 특정 VM(qemu 프로세스)이 원인인지 `virsh list`와 함께 확인합니다.
3. 지속적으로 높으면 임계치가 사이트 기준에 맞는지(공급자 설정의 판정 임계치) 검토합니다.
""",
    "memory": """## 메모리 사용률
1. `free -h`에서 available 기준 실사용률을 확인하고, 캐시가 아닌 실제 사용량이 높은지 봅니다.
2. `ps aux --sort=-rss | head`로 상위 프로세스를 확인합니다. Controller는 MySQL·RabbitMQ, Compute는 qemu가 대부분입니다.
3. 오버커밋된 Compute는 인스턴스 재배치를 검토합니다.
""",
    "disk": """## 디스크 사용률
1. `df -h`로 어느 파티션이 임계치를 넘었는지 확인합니다.
2. `/var/log` 증가는 로그 회전 설정, `/var/lib/glance`·`/var/lib/nova`는 이미지·인스턴스 정리를 검토합니다.
3. `du -xsh /var/* | sort -h | tail`로 큰 디렉터리를 찾고, 삭제 전에 사용 중인 파일인지 확인합니다.
4. 정리 후 사용률이 내려갔는지 재점검합니다.
""",
    "failed_units": """## 실패한 시스템 서비스
1. `systemctl --failed`로 실패한 unit을 확인하고 `journalctl -u <unit> -n 50`으로 원인을 봅니다.
2. 일회성 unit(예: 부팅 시 스크립트)이면 `systemctl reset-failed <unit>`로 정리합니다.
3. 상시 서비스면 원인을 고친 뒤 `systemctl restart <unit>`로 복구하고 다시 실패하지 않는지 확인합니다.
""",
    "kernel_errors": """## 커널 오류
1. `dmesg -T --level=err,crit,alert,emerg | tail -50`으로 오류 메시지와 시각을 확인합니다.
2. 디스크 I/O 오류, NIC 링크 다운, 메모리 ECC 오류는 하드웨어 점검(SMART, 벤더 로그)으로 연결합니다.
3. 반복되는 무해한 메시지는 벤더 확인 후 예외 처리 또는 제외 패턴으로 관리합니다.
""",
    "nic_state": """## 물리·가상 인터페이스
1. `ip -br link`에서 DOWN 또는 NO-CARRIER 인터페이스를 확인합니다.
2. 사용하지 않는 포트면 예외 처리에 노드별로 등록합니다.
3. 사용 중인 포트면 케이블·스위치 포트를 확인하고 `ip link set <nic> up`으로 올린 뒤 재점검합니다.
""",
    "ovs_state": """## Open vSwitch
1. `ovs-vsctl show`에서 error 또는 "could not open network device" 포트를 확인합니다.
2. 브리지가 없으면 `systemctl status openvswitch-switch`와 neutron-openvswitch-agent 상태를 확인합니다.
3. 오류 포트가 삭제된 VM의 잔여 포트면 에이전트가 정리하도록 재시작하거나 `ovs-vsctl del-port`로 정리합니다.
""",
    "smart_health": """## 물리 디스크 SMART
1. `smartctl -H /dev/<disk>`와 `smartctl -A`에서 FAILED/Pre-fail 항목(Reallocated, Pending, Uncorrectable)을 확인합니다.
2. RAID 컨트롤러 뒤의 디스크는 `-d megaraid,N` 등 컨트롤러 옵션이 필요합니다.
3. Pre-fail 디스크는 교체를 계획하고, Ceph/RAID 멤버면 교체 절차에 따라 먼저 제거합니다.
""",
    "raid_health": """## 소프트웨어 RAID
1. `cat /proc/mdstat`에서 [U_] 같은 Degraded 표시와 재구성 진행률을 확인합니다.
2. `mdadm --detail /dev/mdX`로 실패한 멤버 디스크를 찾습니다.
3. 디스크 교체 후 `mdadm --add /dev/mdX /dev/sdY`로 재구성하고 완료까지 모니터링합니다.
""",
    "instance_storage": """## 인스턴스 저장소
1. `df -h /var/lib/nova/instances`로 사용률을 확인합니다.
2. `du -sh /var/lib/nova/instances/*`로 큰 인스턴스와 `_base` 캐시 이미지를 확인합니다.
3. 삭제된 VM의 잔여 디렉터리나 오래된 base 이미지는 nova 설정(`remove_unused_base_images`) 확인 후 정리합니다.
4. 정리 후 사용률이 내려갔는지 재점검합니다.
""",
    "vm": """## VM state
1. `openstack server list --all --status ERROR`로 ERROR 인스턴스와 프로젝트를 확인합니다.
2. `openstack server show <id>`의 fault 메시지로 원인(스케줄 실패, 볼륨 연결 실패, 호스트 장애)을 확인합니다.
3. 호스트가 정상이면 `openstack server reboot --hard` 또는 `openstack server set --state active` 후 재확인합니다.
""",
    "volume": """## Volume state
1. `openstack volume list --all --status error`로 error 볼륨을 확인합니다.
2. cinder-volume 로그에서 해당 볼륨 ID의 오류를 찾습니다(백엔드 용량 부족, 연결 실패).
3. 복구 가능한 경우 `cinder reset-state --state available <id>` 후 재시도하고, 생성 실패 잔여물은 사용자와 확인 후 삭제합니다.
""",
    "network": """## Network state
1. `openstack network agent list`에서 DOWN 에이전트를 확인합니다. Neutron 서비스 항목의 조치 가이드를 따릅니다.
""",
}

for _service, _unit, _path in (("Nova", "nova-*", "nova"), ("Neutron", "neutron-*", "neutron"), ("Cinder", "cinder-*", "cinder"), ("Glance", "glance-*", "glance"),
                               ("Manila", "manila-*", "manila"), ("Octavia", "octavia-*", "octavia"), ("Masakari", "masakari-*", "masakari"), ("Swift", "swift-*", "swift"), ("Heat", "heat-*", "heat")):
    RUNBOOKS[f"{_path}_log"] = _LOG_RUNBOOK.format(service=_service, unit=_unit, path=_path)
RUNBOOKS["system_log"] = """## 시스템 로그 오류
1. 상세 결과의 신규·지속 오류 메시지를 확인합니다. `nfs` 관련 메시지는 Mount 항목과 함께 봅니다.
2. `journalctl -p err --since yesterday`로 원문과 발생 서비스를 확인합니다.
3. 하드웨어·커널 메시지는 커널 오류 항목의 가이드를, 서비스 메시지는 해당 서비스 항목의 가이드를 따릅니다.
4. 무해한 반복 메시지는 사유와 함께 로그 오류 제외 패턴에 등록합니다.
"""

GENERIC_RUNBOOK = """## 조치 가이드
1. 상세 결과의 원본 출력과 특이사항에서 판정 근거를 확인합니다.
2. 같은 노드의 다른 주의 항목과 로그 항목을 함께 확인해 공통 원인을 찾습니다.
3. 조치 후 해당 항목을 재점검하고, 사이트 고유 절차가 있으면 이 가이드를 편집해 남깁니다.
"""


def default_runbook(item_key: str) -> str | None:
    return RUNBOOKS.get(item_key)


def effective_runbook(item_key: str, overrides: dict | None) -> dict:
    """Site override → built-in → generic fallback."""
    override = (overrides or {}).get(item_key)
    if isinstance(override, str) and override.strip():
        return {"item_key": item_key, "text": override, "source": "provider"}
    built_in = default_runbook(item_key)
    if built_in:
        return {"item_key": item_key, "text": built_in, "source": "builtin"}
    return {"item_key": item_key, "text": GENERIC_RUNBOOK, "source": "generic"}
