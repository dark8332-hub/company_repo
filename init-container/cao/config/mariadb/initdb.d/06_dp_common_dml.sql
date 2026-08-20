-- cm_provider_type
INSERT INTO dp_common.cm_provider_type
(id, name, description, delete_yn, reg_dt) VALUES
(1, 'openstack', 'openstack', 'N', '2024-07-29 04:41:31.000'),
(2, 'kubernetes', 'kubernetes', 'N', '2024-07-29 04:42:06.000'),
(3, 'ncp', 'ncp', 'N', '2024-07-29 04:42:07.000'),
(4, 'aws', 'aws', 'N', '2024-07-29 04:42:07.000');

-- cm_resource_type_kind
INSERT INTO dp_common.cm_resource_type_kind
(id, name, description, delete_yn, reg_dt)VALUES
(1, 'openstack', NULL, NULL, NULL),
(2, 'kubernetes', NULL, NULL, NULL),
(3, 'aws', NULL, NULL, NULL);

-- cm_resource_type
-- openstack
INSERT INTO dp_common.cm_resource_type (id, resource_type_kind_id, name, description, delete_yn, reg_dt) VALUES
(1000, 1, 'OS_IMAGE', '인스턴스 기초 설정에 필요한 이미지', 'N', now()),
(1001, 1, 'OS_KEY_PAIR', '인스턴스 기초 설정에 필요한 키페어', 'N', now()),
(1002, 1, 'OS_FLAVOR', '인스턴스 기초 설정에 필요한 인스턴스 유형', 'N', now()),
(1003, 1, 'OS_SERVER_GROUP', '인스턴스 기초 설정에 필요한 배치 그룹', 'N', now()),
(1004, 1, 'OS_VM', 'VM 정보', 'N', now()),
(1005, 1, 'OS_VM_SNAPSHOT', 'VM 스냅샷 정보', 'N', now()),
(1006, 1, 'OS_VOLUME', '볼륨 정보', 'N', now()),
(1007, 1, 'OS_VOLUME_SNAPSHOT', '볼륨 스냅샷 정보', 'N', now()),
(1008, 1, 'OS_VOLUME_TYPE', '볼륨 타입 정보', 'N', now()),
(1009, 1, 'OS_VOLUME_BACKUP', '볼륨 백업 정보', 'N', now()),
(1010, 1, 'OS_VOLUME_BACKUP_SCHEDULE', '볼륨 백업 스케쥴링 정보', 'N', now()),
(1011, 1, 'OS_SHARE_FILE_SYSTEM', '공유 파일 시스템 정보', 'N', now()),
(1012, 1, 'OS_OBJECT_STORAGE', '오브젝트 스토리지 정보', 'N', now()),
(1013, 1, 'OS_SEGMENT', '네트워크 세그먼트 정보', 'N', now()),
(1014, 1, 'OS_ROUTER', '네트워크 라우터 정보', 'N', now()),
(1015, 1, 'OS_FLOATING_IP', '네트워크 유동 IP 정보', 'N', now()),
(1016, 1, 'OS_LOAD_BALANCER', '네트워크 로드밸런서 정보', 'N', now()),
(1017, 1, 'OS_SECURITY_GROUP', '네트워크 보안 그룹 정보', 'N', now()),
(1018, 1, 'OS_STACK', '오케스트레이션 스택 정보', 'N', now()),
(1019, 1, 'OS_RESOURCE_TYPE', '오케스트레이션 리소스 타입 정보', 'N', now()),
(1020, 1, 'OS_TEMPLATE_VERSION', '오케스트레이션 템플릿 버전 정보', 'N', now()),
(1021, 1, 'OS_RACK_STRUCTURE', '렉 구성도 정보', 'N', now()),
(1022, 1, 'OS_SWITCH_STRUCTURE', '스위치 구성도 정보', 'N', now()),
(1023, 1, 'OS_HOST_STRUCTURE', '호스트 구성도 정보', 'N', now()),
(1024, 1, 'OS_NETWORK_TOPOLOGY', '네트워크 토폴로지 정보', 'N', now()),
(1025, 1, 'OS_AVAILABILITY_SEGMENT', '고 가용성 설정 정보', 'N', now()),
(1026, 1, 'OS_AVAILABILITY_HOST', '고 가용성 호스트 정보', 'N', now()),
(1027, 1, 'OS_PROJECT', '오픈스택 프로젝트 정보', 'N', now()),
(1028, 1, 'OS_USER', '오픈스택 사용자 정보', 'N', now()),
(1029, 1, 'OS_HYPERVISOR', '오픈스택 하이퍼바이저 정보', 'N', now()),
(1030, 1, 'OS_HOST_AGGREGATES', '오픈스택 호스트 그룹 정보', 'N', now()),
(1031, 1, 'OS_STORAGE_BACKEND', '오픈스택 스토리지 백엔드 정보', 'N', now()),
(1032, 1, 'OS_SYSTEM_INFO', '오픈스택 엔드포인트 정보', 'N', now());

-- kubernetes
INSERT INTO dp_common.cm_resource_type (id, resource_type_kind_id, name, description, delete_yn, reg_dt) VALUES
(2000, 2, 'K8S_CLUSTER', 'k8s', 'N', now()),
(2001, 2, 'K8S_NODE', 'k8s', 'N', now()),
(2002, 2, 'K8S_NAMESPACE', 'k8s', 'N', now()),
(2003, 2, 'K8S_POD', 'k8s', 'N', now()),
(2004, 2, 'K8S_SERVICE', 'k8s', 'N', now()),
(2005, 2, 'K8S_CONTAINER', 'k8s', 'N', now());

INSERT INTO dp_common.cm_resource_type (id, resource_type_kind_id, name, description, delete_yn, reg_dt) VALUES
(3000, 3, 'AWS_VPC', 'vpc', 'N', now()),
(3001, 3, 'AWS_SUBNET', 'subnet', 'N', now()),
(3002, 3, 'AWS_SECURITY_GROUP', 'security_group', 'N', now()),
(3003, 3, 'AWS_EC2', 'ec2', 'N', now()),
(3004, 3, 'AWS_NETWORK_ACL', 'network_acl', 'N', now()),
(3005, 3, 'AWS_INTERNET_GATEWAY', 'internet_gateway', 'N', now()),
(3006, 3, 'AWS_ELASTIC_IP', 'elastic_ip', 'N', now()),
(3007, 3, 'AWS_NAT_GATEWAY', 'nat_gateway', 'N', now()),
(3008, 3, 'AWS_NETWORK_INTERFACE', 'network_interface', 'N', now()),
(3009, 3, 'AWS_ROUTE_TABLE', 'route_table', 'N', now());

-- cm_config_type
INSERT INTO dp_common.cm_config_type
(id, name, description, delete_yn, reg_dt) VALUES
(1, 'opensatck', 'openstack', 'N', '2024-12-16 04:41:31.000'),
(2, 'kubernetes', 'k8s', 'N', '2024-12-16 04:41:31.000'),
(3, 'aws', 'ec2', 'N', '2024-12-16 04:41:31.000'),
(4, 'vmsare', 'vmware', 'N', '2024-12-16 04:41:31.000');