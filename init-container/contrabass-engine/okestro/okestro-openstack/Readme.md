# Contrabass OpenStack 배포 Ansible

## 변경사항

| 번호 | 날짜 | 변경 내용 |
|--|--|--|
| 1 | 24/04/09 | 최초 커밋 및 `cinder.keyring`을 Compute Node로 복사 |
| 2 | 24/04/11 | `Octavia-set`의 `main.yml` 수정 |
| 3 | 24/04/12 | Octavia `main.yml` 주석 제거 |
| 4 | 24/04/15 | 방화벽 비활성화 처리 수정 |
| 5 | 24/04/16 | Manila HTTPS Python 코드 수정<br>Controller 그룹 내 Compute Host용 Masakari 수정<br>`octavia-interface.sh.j2` 수정<br>Ceph Keyring 복사 처리 수정 |
| 6 | 24/04/17 | `masakari-dashboard.sh.j2` 수정<br>`openstack-dashboard.conf.j2` 수정 |
| 7 | 24/04/18 | Purge 수정 및 `libvirt` 사용자 삭제 작업 추가 |
| 8 | 24/04/19 | OpenStack 업그레이드(Wallaby -> Yoga) Ansible 추가 |
| 9 | 24/04/22 | TLS 마이그레이션 추가 |
| 10 | 24/04/23 | `placement-init.yml` 수정<br>`Octavia-interface-daemon` 수정<br>Compute Node Purge 추가<br>Masakari Public Endpoint 생성 수정 |
| 11 | 24/04/24 | Masakari Dashboard Yoga 버전 설치 방식을 수동 설치에서 패키지 설치로 수정<br>`Octavia-set cloud.yml.j2`에 verify 옵션 추가<br>Masakari `masakari-dashboard.yml`에 Apache daemon 재시작 추가<br>Masakari task `masakari-dashboard.yml` 오타 수정<br>Certificate task `main.yml`, `generate-server.yml` 수정<br>`pakage_ip`를 `package_ip`로 수정<br>Ceph 및 `main.yml` 변경<br>Certificate `check.yml` task 주석 처리 수정<br>`local.repo.j2` 수정<br>`main.yml` task 수정<br>Manila 디렉터리 `default`를 `defaults`로 수정<br>Swift role의 `main.yml` 수정 |
| 12 | 24/04/25 | Prometheus role 수정<br>`inventory/group_vars/all/main.yml`에 RadosGW Interface 값 추가<br>Swift HAProxy 설정 task 수정 |
| 13 | 24/04/26 | `okestro-openstack main.yml`의 Prometheus hosts를 `storage`에서 `radosgw`로 수정<br>Prometheus task `main.yml`의 `radosgw-user-setting` host group을 `storage`에서 `radosgw`로 수정<br>Prometheus task `radosgw-user-setting`의 HAProxy 설정 삭제<br>Prometheus task `s3cmd-install`에 HAProxy RadosGW 설정 추가<br>Ceph 사용 시 `octavia-set` task `octavia-basic-set.yml`의 Amphora image 업로드 삭제 |
| 14 | 24/04/29 | Purge Ansible의 `libvirt-dnsmasq` 사용자 삭제 task에서 `remove: true` 삭제 |
| 15 | 24/05/07 | TLS 마이그레이션 role 추가<br>TLS 마이그레이션에 따른 certificate role 삭제<br>`main.yml` task에 TLS 마이그레이션 추가<br>Manila TLS Python 코드 수정<br>Main task `check-certificate`에서 certificate role 삭제<br>`tls-migration` role에 `never-delete.txt` 파일 추가 |
| 16 | 24/05/08 | Prometheus role의 `prometheus.yml.j2`, `monitoring-server.conf.j2` template 수정<br>Manila 코드 수정<br>`enable_openstack_tls`용 TLS 마이그레이션 수정<br>Heat-init 오류 코드 수정<br>`tls-migration` role의 template 디렉터리 수정<br>New-compute `addnode.yml` task 파일 및 role 추가<br>HAProxy 구성 확인 로직 추가 |
| 17 | 24/05/09 | Ceph Cluster 연결 관련 Manila task 추가<br>Add Node task 수정<br>Masakarimonitor task 재시작 처리 수정<br>Addnode role 수정 |
| 18 | 24/08/07 | Ceph-Ansible과 Okestro-Openstack-Ansible 통합<br>배포 속도 개선을 위해 일부 task 제거<br>자체 서명 인증서 수정<br>Heat HTTPS endpoint 지원 수정<br>Domain endpoint 및 HTTPS 지원 추가<br>일부 `group_vars` 변수 제거<br>All-in-one 모델 Contrabass Portal 및 Contrabass Mole 배포 추가<br>`enable_openstack_tls: false`일 때 TLS를 보장하지 않도록 TLS 지원 수정<br>Play 실행 전 `ssh-copy-id`가 필요 없도록 SSH Key 교환 자동화 추가<br>Playbook tag 수정 |
| 19 | 24/08/08 | Ceph config 복사 수정 |
| 20 | 24/08/09 | Swift endpoint 수정 |
| 21 | 24/08/12 | Swift 및 Cinder volume 재시작 task 수정<br>`cinder-volume` clustering 및 단일 volume backend binary 제거<br>변수 수정 |
| 22 | 24/08/23 | Heat config에 `memcached_servers` 옵션 추가 |
| 23 | 24/09/05 | `chrony.conf` 긴급 수정 |
| 24 | 24/11/21 | Thanos storage 옵션 및 TLS 옵션 수정<br>Nova NoVNC HAProxy 설정 수정<br>Share backend 설정 전 `manila-share` 재시작 task 삭제<br>SSL message excessive size 오류 수정 |
| 25 | 24/11/22 | Prometheus main task 오타 수정<br>Barbican 설치 추가<br>Fedora OS SSL 인증 오류 수정<br>사용하지 않는 Amphora image 제거 |
| 26 | 24/11/25 | Thanos task 및 template 정상 실행되도록 수정<br>Contrabass-mole TLS 설정 수정 |
| 27 | 24/11/27 | Contrabass-mole TLS 설정 오타 수정 |
| 28 | 24/12/02 | Monitoring HA 활성화 조건문 수정 |
| 29 | 24/12/30 | Fedora OS Contrabass Ansible 호환성 업데이트 수정<br>Fedora OS의 `ceph-volume` 수정<br>RHEL 9 미만의 Percona, Keystone, Glance, Compute에서 module disable이 실행되지 않도록 수정<br>Chrony handler 수정<br>RabbitMQ `LimitNOFILE=65535` 설정값 추가<br>`all.yml`에서 `pac_wsgi`: `mod_wsgi` -> `python3-mod_wsgi` 변경<br>Cinder task에 `cinder-api` 재시작 추가<br>Horizon task config 파일 설정 그룹을 전역 변수로 변경 |
| 30 | 25/02/12 | Contrabass 및 Viola Instance 생성 기능 추가<br>`Octavia.conf` 수정<br>Contrabass 및 Viola Instance 생성 기능 추가<br>`octavia.conf`의 `controller_ip_port_list` 옵션 수정<br>Certificate task에 인증서 삭제 추가<br>Cinder backend 명명 규칙 정의 |
| 31 | 25/02/17 | v1.5.0 Contrabass-Ansible 수정<br>Certificate task에서 인증서 삭제<br>RabbitMQ task `config.yml` 수정<br>`cinder-api` 시작 task 수정 |
| 32 | 25/02/26 | v1.5.1 Contrabass-Ansible 수정<br>RabbitMQ durable 및 notifications config 추가<br>Octavia Interface Network band 변경 수정 |
| 33 | 25/02/27 | RabbitMQ admin 사용자 및 admin/openstack 사용자에 administrator tag 추가<br>`internal_vip_subnet(24cidr)` 권한을 MySQL root 사용자에 추가<br>Contrabass Mole 설치 수정 및 Mole config 파일 추가<br>Contrabass Mole용 IPMI 사용자, password 변수 및 `snmp`, `lldpd` 패키지 추가 |
| 34 | 25/03/06 | Contrabass-mole binary 업데이트 |
| 35 | 25/03/07 | AMQP durable 옵션 비활성화 |
| 36 | 25/03/28 | `contrabass-mole.tar.gz` 업데이트 |
| 37 | 25/04/04 | Add node 업데이트<br>Certificate 수정<br>TLS-Migration role 삭제 |
| 38 | 25/04/07 | 하드코딩된 `cloud1234` password를 `{{ keystone_pass }}`로 수정 |
| 39 | 25/04/09 | Branch를 Portal 버전으로 변경: v1.5 -> v3.0.3 |
| 40 | 25/06/11 | v3.0.4로 버전 업그레이드<br>OpenStack Caracal + SUSE 9.4 또는 OpenStack Caracal + Ubuntu 24.04 구현<br>MinIO 설치 추가<br>`ceph-ansible`을 `cephadm` 배포로 변경<br>Exporter 설치 추가<br>Thanos/Loki를 MinIO object storage와 통합<br>Addnode Ansible 업그레이드 |
| 41 | 25/06/16 | `openstack-exporter` 업데이트 |
| 42 | 25/06/27 | Tech-preview role/task 업데이트<br>Mole 3.0.4 업데이트 |
| 43 | 25/07/01 | Contrabass-mole 3.0.4 긴급 수정 |
| 44 | 25/07/11 | Amphora image를 Yoga에서 Caracal로 업데이트<br>Octavia Python 코드 수정 |
| 45 | 25/07/15 | Prometheus Contrabass-mole job name 수정 |
| 46 | 25/07/29 | Masakari용 SUSE 9.4 Pacemaker repository 업데이트 |
| 47 | 25/08/14 | MinIO attachment 로직 정리 및 backup bucket 생성<br>All-in-one 모델용 MinIO/Percona 배포 업데이트<br>Addnode 수정<br>Contrabass-mole 07/25 업데이트 및 MinIO를 backup storage로 통합 |
| 48 | 25/08/18 | Compute role Neutron template interpolation 수정<br>Masakari monitoring interval을 60에서 10으로 변경<br>VLAN tag 적용을 위한 OVS port mapping 업데이트<br>MinIO HAProxy 옵션 업데이트<br>Cinder configuration `noitification_driver`를 `driver`로 수정 |
| 49 | 25/08/20 | Ceph 배포 device name을 device path로 업데이트<br>Ceph integration RBD pool 초기화 추가 |
| 50 | 25/09/01 | MySQL configuration 오타 긴급 수정 |
| 51 | 25/09/17 | CVE 대응을 위해 RabbitMQ 버전을 4.1.2로 업데이트<br>Contrabass-mole 업데이트 |
| 52 | 25/10/14 | Contrabass-mole 업데이트 |
| 53 | 25/10/20 | Ceph HAProxy config 업데이트 및 일부 버그 workaround 적용<br>Ceph Exporter 및 Promtail 업데이트<br>`ceph-cluster.yaml.j2` 파일 수정 |
| 54 | 25/10/27 | Caracal 버전용 `os_brick` patch 업데이트<br>Grafana Contrabass monitoring dashboard 이슈 patch에 따라 Loki 및 Promtail configuration 업데이트 |
| 55 | 25/10/29 | IPMI Exporter systemd unit이 올바른 executable path를 사용하도록 수정 |
| 56 | 25/11/03 | Mole 버전을 3.0.4에서 3.0.4.22로 업데이트<br>Prometheus configuration을 Mole exporter와 통합 |
| 57 | 25/11/04 | Mole config 파일의 exporter bind port 중복 수정 |
| 58 | 25/11/05 | SSH key 복사 로직 리팩터링 - v3.0.5 |
| 59 | 25/11/10 | Libvirt TLS configuration을 OpenStack TLS 처리와 분리<br>InnoDB buffer pool size를 128M에서 4G로 조정하고 instance size를 1에서 4로 조정 |
| 60 | 25/11/11 | Monitoring certificate 생성 작업을 certificate role로 병합 |
| 61 | 25/11/12 | `glance-api.conf` 오타 수정<br>Epoxy repository 추가 및 sysfsutils env role 설치 |
| 62 | 25/11/13 | Monitoring network 변수 추가 및 Heat/Contrabass Portal 변수 제거(v3.0.5에서 deprecated)<br>HAProxy role 수정: Monitoring VIP resource 추가, resource constraint를 resource group으로 수정, `haproxy.cfg.j2` 수정<br>MinIO role 수정: MinIO Cluster가 사용하는 internal API network를 monitoring network로 변경<br>Octavia Interface Scripts File 수정: Controller Node가 nameserver용 `neutron-dhcp-agent`에 침범되지 않도록 방지<br>Monitoring certificate 생성 누락 조건식 추가<br>Keystone, Glance HAProxy configuration 교체 |
| 63 | 25/11/14 | `contrabass-exporter`(`libvirt-exporter`) 버전을 `zhangjianweibj`에서 `inovex 1.7.2`로 업그레이드<br>`contrabass-exporter.service` option flag 수정 |
| 64 | 25/11/17 | Placement, Nova, Neutron configuration 교체<br>Cinder, Octavia, Barbican configuration 교체<br>Octavia-set configuration 교체 및 `lb-mgmt-subnet` gateway 제거<br>Compute configuration 교체<br>Ceph RGW integration configuration 교체<br>Manila, Swift configuration 교체<br>Masakari를 Contrabass 3.0.5에 맞게 수정(`masakari-monitors` 제거)<br>Monitoring network를 사용하도록 Prometheus 수정<br>`main.yml` 갱신 |
| 65 | 25/11/18 | Masakari untar task 수정<br>단일 role 실행 시 Barbican handler로 인해 발생하는 오류 때문에 Barbican handler 제거 |
| 66 | 25/11/19 | `ansible-key-initialization.yml` 파일 수정<br>Ubuntu 24.04 + OpenStack Caracal 초기 배포 후 Horizon 접근 오류 수정<br>Compute role에서 사용하는 `nova.conf`, `neutron.conf` template 파일 오타 수정<br>`contrabass-exporter.yaml` 파일의 YAML 문법 오류 수정<br>Ubuntu 24.04에서 초기 Compute role 배포 후 AppArmor가 활성 상태로 남는 문제 수정<br>Libvirt image에 RBD를 사용할 때 evacuate 작업 후 `nova/instances` 디렉터리가 남는 문제 수정<br>Horizon `local_settings.py` template 파일 업데이트 |
| 67 | 25/11/25 | Textfile collector service `ings.py` template 파일 추가<br>Compute에서 `aa-teardown` 실행 시 오류 무시 |
| 68 | 25/11/26 | Nova scheduler filter 업데이트 |
| 69 | 25/11/27 | Loki compaction 및 retention 업데이트<br>기본 log retention을 30일로 설정 |
| 70 | 25/11/28 | Thanos compact service 및 retention period 업데이트 |
| 71 | 25/12/01 | Ubuntu 24.04 초기 Compute role 배포 후 AppArmor가 활성 상태로 남는 문제 최종 수정 |
| 72 | 25/12/02 | RabbitMQ heartbeat를 120초로 업데이트(`timeout_threshold=120`, `rate=2`) |
| 73 | 25/12/03 | `fs.file-max = 1000000`을 sysctl에 설정해 system-wide file descriptor limit 증가<br>설치 후 `masakari.tar` 파일이 삭제되지 않는 문제 수정<br>모든 OpenStack component API worker를 6으로 설정<br>Contrabass-engine middleware 및 OpenStack log 디렉터리 구성<br>`textfile_collector` script 수정<br>MinIO bucket 사용 정책 연결 시 sleep delay 추가<br>새 Promtail log target 추가 및 관련 task 업데이트 |
| 74 | 25/12/05 | `ml2.conf`가 VLAN type을 기본값으로 사용하도록 업데이트 |
| 75 | 25/12/08 | Contrabass-mole 업데이트(12/05) |
| 76 | 25/12/09 | Compute role에 `os-brick` 업데이트<br>Manila용 `oslo_concurrency` 디렉터리 업데이트<br>`my.cnf` 권한 업데이트<br>보안 취약점 대응을 위해 Keystone/Glance/Placement database 사용자 생성 수정<br>보안 취약점 대응을 위해 Placement WSGI config 수정<br>보안 취약점 대응을 위해 Nova/Neutron/Cinder/Octavia/Barbican/Manila/Masakari database host 생성 수정 |
| 77 | 25/12/10 | `loki.service` 파일 업데이트<br>`openstack-exporter.service` 파일 업데이트 |
| 78 | 25/12/11 | 보안 취약점 대응을 위해 Placement WSGI config 수정 업데이트<br>Nova database 생성 교체<br>보안 취약점 대응을 위해 Horizon 및 web server configuration 업데이트<br>보안 취약점 대응을 위해 Keystone WSGI configuration 업데이트<br>`promtail-config` 파일 업데이트 |
| 79 | 25/12/12 | Addnode role 수정<br>Addnode role 업데이트 |
| 80 | 25/12/15 | Reshaper API를 사용하도록 Placement role assignment 업데이트 |
| 81 | 25/12/16 | `rabbitmq-exporter` binary를 RabbitMQ plugin으로 변경 |
| 82 | 25/12/16 | 기존 Contrabass purge playbook을 `purge.bak`으로 이동<br>Purge playbook용 `inventory.ini` 수정<br>Compute 및 Cluster Purge Playbook 추가<br>Compute Purge Role 추가<br>Cluster Purge Role 추가<br>Purge playbook용 `main.yml` 수정 |
| 83 | 25/12/17 | Ubuntu에서 Compute Node purge 시 Ceph가 손상되지 않도록 `purge-compute` 수정 |
| 84 | 25/12/18 | SUSE용 `purge-compute` 수정: purge 후 남은 systemd/junk 파일 제거를 위한 정리 추가 및 Ceph 손상 방지 |
| 85 | 25/12/22 | `purge-cluster`에 Ceph cluster purge 추가<br>Nova conductor/scheduler worker 업데이트<br>Octavia health manager worker 업데이트<br>RabbitMQ `notifications.*` queue TTL을 24시간으로 업데이트 |
| 86 | 25/12/23 | Process worker용 Cinder template 및 `barbican-api` config 수정<br>Purge-Cluster role에 Ubuntu v3.0.4 변수 추가<br>Compute template 수정: controller-only 설정용 `nova.conf`/`neutron.conf` 및 process worker용 Cinder template 수정<br>Purge-Cluster에 Debian purgecluster의 `epmd` process kill task 추가 |
| 87 | 25/12/24 | 잘못된 template 수정 |
| 88 | 25/12/26 | Masakari template 수정: service update period 180 -> 600, verify interval 1 -> 3 |
| 89 | 25/12/29 | Addnode role의 `migration-settings.yml` 수정<br>Addnode role의 `/etc/hosts` template 파일 수정<br>Addnode role에서 `chronyd` service daemon 활성화 |
| 90 | 25/12/30 | Purge-Cluster `ceph.yml` 수정: SUSE용 `python3-jinja2` 설치 패키지 추가 |
| 91 | 26/01/05 | Horizon 수정: Debian용 Horizon symlink 추가 및 `apache2.conf` 수정 |
| 92 | 26/01/08 | Cephadm by-path 조회 로직 수정<br>Thanos compact 설치 task 업데이트 |
| 93 | 26/01/12 | Horizon 수정: `horizon-symlinks` task를 Debian 전용으로 변경 |
| 94 | 26/01/14 | Prometheus job 추가(`ceph-core`)<br>Custom container 및 HAProxy VIP 추가<br>SUSE용 journal log path 수정<br>Ceph-exporter 변경: Ceph network에서 monitoring network로 변경<br>Ceph에서 Grafana service 삭제 |
| 95 | 26/01/28 | v3.0.5에서 tech-preview 제거 |
| 96 | 26/02/02 | Contrabass Mole 및 config 파일 업데이트 |
| 97 | 26/02/06 | `nvmeof`, `nvmeof-cli` image 추가<br>`cephadm-bootstrap.yml`, `create-private-registry.yml` 수정 |
| 98 | 26/02/10 | Ceph inventory 업데이트<br>Contrabass-mole binary 및 default config option 업데이트 |
| 99 | 26/02/12 | Purge-Ansible 수정: 잔여 파일 및 관련 service 정리<br>`purge-compute` play 실행 시 Pre-task에 compute-service 비활성화 추가 |
| 100 | 26/02/13 | Contrabass-mole binary 업데이트 |
| 101 | 26/02/25 | Contrabass-mole binary 업데이트<br>Nova compute timeout 옵션 추가 |
| 102 | 26/02/26 | `ceph-core` HAProxy 옵션 수정 |
| 103 | 26/02/26 | Nova 29.2.0 repository 및 `sources.list` 파일 업데이트 |
| 104 | 26/03/03 | Alertmanager HAProxy 추가<br>Ceph image file version 19.2.3 업데이트<br>Cephadm 및 Ceph-common 19.2.3 repository와 `local.repo` 파일 업데이트<br>`purgecluster-ceph.yml`의 Ceph image를 v19에서 v19.2.3으로 수정<br>`cephadm-installation.yml`의 Apt-Mark 업데이트 |
| 105 | 26/03/04 | Ceph OSD용 `inventory.ini` 파일 수정<br>Ceph 미사용 시 Octavia image 복사 로직 업데이트<br>v3.0.6 및 Ceph에서 변수 단순화 작업<br>Ubuntu OS 사용 시 자동 패키지 업그레이드 비활성화<br>단순화를 위해 bridge name 변수 제거<br>Percona config 수정: `set wsrep gmcast.listen_addr`<br>RabbitMQ quorum queue 적용<br>Prometheus 버전 업그레이드(2.45.3 -> 3.5) |
| 106 | 26/03/05 | RabbitMQ role `main.yml` 수정: `create_users.yml` -> `rabbitmq_users.yml`<br>Ceph Custom Container 버전 1.5.2 -> 1.5.8 업데이트 |
| 107 | 26/03/06 | Log metric exporter를 Promtail에서 Alloy로 변경 |
| 108 | 26/03/09 | Alloy config 오타 수정 |
| 109 | 26/03/25 | 보안 취약점 패치: Security role 및 Security playbook 업데이트<br>보안 취약점 패치: Percona role 업데이트<br>보안 취약점 패치: OpenStack DB create 업데이트<br>보안 취약점 패치: Contrabass role 업데이트<br>보안 취약점 패치: `inventory/main.yml` 업데이트<br>`enable_masakari_only` 추가 및 Pacemaker no quorum policy를 stop으로 설정 |
| 110 | 26/03/26 | Ceph Custom Container 버전 1.5.8 -> 1.6.9 업데이트 |
| 111 | 26/03/27 | `enable_masakari_only` 수정: Memcached listener IP 및 OpenStack config 파일 quorum 설정 변경<br>Ubuntu 24.04.3 repository 업데이트: `inventory/main.yml`, `source-list` template 수정 |
| 112 | 26/04/01 | `enable_masakari_only` 수정: OpenStack config 파일 quorum 설정 변경 및 `nova.conf`에 retry 옵션 추가<br>`nova.conf` 업데이트<br>`nova.conf`의 retry 옵션 업데이트 |
| 113 | 26/04/03 | RHEL environment role 수정: systemd `LimitNOFILE` 수정(Default: 1024 -> 65536)<br>RHEL Compute role 수정: `virtproxyd.socket` 비활성화<br>RabbitMQ role 수정: notification queue TTL policy 수정<br>Masakari role 수정: Masakari handler 수정<br>Ubuntu Env Role 수정: `oslo.messaging-14.7.2-py3` 설치<br>Percona template 수정: `my.cnf` template 수정 |
| 114 | 26/04/06 | RHEL role 수정: `virtqemud` 비활성화 및 Keystone configuration 디렉터리 권한 수정 |
| 115 | 26/04/07 | RabbitMQ role 수정: notification queue TTL policy 수정(`message-ttl: 600000 -> 300000`)<br>Add node 수정: Promtail -> Alloy 변경, `virtqemud` 비활성화, `oslo.messaging` 설치 |
| 116 | 26/04/08 | Prometheus role 수정: MySQL non-primary를 primary로 변경 및 `openstack-exporter` collection metrics 비활성화<br>Prometheus role 수정: MySQL non-primary를 primary로 편집 |
| 117 | 26/04/09 | Ceph Custom Container 버전 1.6.9 -> 1.7.1 업데이트 |
| 118 | 26/04/10 | RHEL role 수정: `virtqemud` 비활성화 |
| 119 | 26/04/30 | Ceph Custom Container 버전 1.7.1 -> 1.7.2 업데이트<br>HA를 위한 수정: OpenStack component `oslo_messaging_rabbit` 수정, OpenStack DB 관련 HAProxy 옵션 수정, Masakari `service_token` 옵션 추가, Nova Database DB Pool 옵션 추가 |
| 120 | 26/05/06 | `contrabass-engine/okestro/okestro-openstack/opentofu/openstack` 경로에 파일 업로드 |
| 121 | 26/05/13 | Ceph Custom Container 버전 1.7.2 -> 1.7.3 업데이트 |
| 122 | 26/05/18 | Ubuntu 24.04.3 / Caracal 환경 Cinder Version Up  ( v 24.5.0 ), Openstack Exporter haproxy 리소스 등록 추가 |
| 123 | 26/05/21 | Ubuntu 24.04.3 레포지토리 경량화로 인한 커스텀화, gpg 키 무시 옵션 sources.list 파일 수정 |
| 124 | 26/05/27 | Ceph Custom Container 버전 1.7.3 -> 1.7.4 업데이트 |
| 125 | 26/05/29 | Ceph Custom Container 버전 1.7.4 -> 1.7.5 업데이트 |
| 126 | 26/06/01 | Ceph Custom Container 버전 1.7.5 -> 1.7.6 업데이트 |
| 127 | 26/06/05 | Ceph Custom Container 버전 1.7.6 -> 1.7.7 업데이트<br>cephadm role에 files의 이미지 변경, templetes/predictor_custom_container.yml.j2, task/ceph-custom-container-install.yml 버전 표기 업데이트 |
| 128 | 26/06/10 | Exporter 경량화 설정 : 불필요 메트릭 수집 제외<br>Prometheus 경량화 설정 : metric_relabel_configs / retention / scrape 설정 정리<br>Thanos 경량화 설정 : Compact 다중 실행 방지, Block Retention / Downsample 정책 정리, Query Frontend 응답 캐시 설정, Query auto-downsampling 적용, Compactor 상태 모니터링 추가, Downstream HTTP Connection Pool 및 Partial Response 설정 튜닝 |
| 129 | 26/06/12 | mole 이미지 업데이트 및 contrabass templates의 agent.local.yml.j2 파일 Proxy 설정 추가  |
| 130 | 26/06/16 | thanos-query-front.service 파일 오타 수정  |
| 130 | 26/06/16 | thanos-query-front.service 파일 오타 수정  |
| 131 | 26/06/18 | Ubuntu 24.04.3 / Caracal Cinder Version Up cinder-install.yml 파일내용 누락분 추가( cinder apt package 를 설치하지 않도록함 ) |
| 132 | 26/06/29 | Alertmanager.yml 파일 수정 : Galera 알림 라우팅 관련 수정 |
| 133 | 26/06/30 | loki-s3-config.yaml 파일 수정 : Loki memberlist 바인드 주소 설정 |
