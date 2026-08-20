CREATE DATABASE IF NOT EXISTS `dp_common`; 

use dp_common;

CREATE TABLE `cb_app_type` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'application id',
  `app_name` varchar(15) DEFAULT NULL COMMENT 'application name',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='작업이력 어플리케이 info';

CREATE TABLE `cb_event_log_type` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `event_type` varchar(255) NOT NULL COMMENT '이벤트 유형, 예: compute__do_build_and_run_instance',
  `component` varchar(50) NOT NULL COMMENT '관련 컴포넌트, 예: Nova, Cinder, Keystone, Neutron',
  `display_name` varchar(100) NOT NULL COMMENT '이벤트의 구체적인 작업, 예: 인스턴스 생성, 인스턴스 시작',
  `last_step` tinyint(1) NOT NULL DEFAULT 0 COMMENT '이벤트의 마지막 단계 여부',
  `description` text DEFAULT NULL COMMENT '이벤트 설명',
  `created_at` timestamp NULL DEFAULT current_timestamp() COMMENT '이벤트가 생성된 시간',
  PRIMARY KEY (`event_type`),
  UNIQUE KEY `idx_id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=83 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='OpenStack 이벤트 로그를 저장하는 테이블';

CREATE TABLE `cb_log_master` (
  `app_id` bigint(20) NOT NULL COMMENT 'cb_app_type.id',
  `page_id` varchar(50) DEFAULT NULL COMMENT '화면 id',
  `global_request_id` varchar(55) NOT NULL COMMENT 'global X-Openstack-Request-Id',
  `local_request_id` varchar(55) DEFAULT NULL COMMENT 'local X-Openstack-Request-Id',
  `object_id` varchar(255) DEFAULT NULL COMMENT 'uuid',
  `service_type_name` varchar(20) DEFAULT NULL COMMENT '서비스 타입명:instance, instance-snapshot, ..',
  `action_name` varchar(50) DEFAULT NULL COMMENT 'create, delete, update',
  `response_status_code` smallint(5) unsigned DEFAULT NULL COMMENT 'http response status: 200, 404, 500, ..',
  `response_message` text DEFAULT NULL COMMENT 'http response message',
  `created_at` timestamp NULL DEFAULT current_timestamp() COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  PRIMARY KEY (`global_request_id`),
  KEY `FK_app_type_TO_log_master` (`app_id`),
  CONSTRAINT `FK_app_type_TO_log_master` FOREIGN KEY (`app_id`) REFERENCES `cb_app_type` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='작업이력 마스터 테이블';


CREATE TABLE `cb_log_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `component` varchar(20) NOT NULL COMMENT '서비스 타입명: nova, glance..',
  `object_id` varchar(255) DEFAULT NULL COMMENT 'uuid',
  `global_request_id` varchar(55) DEFAULT NULL COMMENT 'global X-Openstack-Request-Id',
  `local_request_id` varchar(55) DEFAULT NULL COMMENT 'local X-Openstack-Request-Id',
  `event_name` varchar(100) DEFAULT NULL,
  `action_name` varchar(100) DEFAULT NULL,
  `response_status_code` smallint(5) unsigned DEFAULT NULL COMMENT 'http response status: 200, 404, 500, ..',
  `message` text DEFAULT NULL,
  `host` varchar(100) DEFAULT NULL,
  `created_at` timestamp(6) NULL DEFAULT current_timestamp(6) COMMENT '등록 일시',
  `updated_at` timestamp(6) NULL DEFAULT NULL COMMENT '수정 일시',
  `oslo_timestamp` timestamp(6) NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_log_master_TO_log_detail` (`global_request_id`),
  CONSTRAINT `FK_log_master_TO_log_detail` FOREIGN KEY (`global_request_id`) REFERENCES `cb_log_master` (`global_request_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='작업이력 상세 테이블';

CREATE TABLE `cb_baton_attr` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `key` varchar(100) DEFAULT NULL,
  `value` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `cb_baton_log_table` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `log_level` varchar(255) NOT NULL,
  `target` varchar(255) NOT NULL,
  `detail` varchar(255) DEFAULT NULL,
  `log_message` text NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `insert_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5022772 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `cb_code_group` (
  `code` varchar(128) NOT NULL,
  `name` varchar(256) DEFAULT NULL,
  `description` varchar(1024) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp() COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT 0 COMMENT '삭제 상태',
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='그룹코드';

CREATE TABLE `cb_common_code` (
  `group_code` varchar(128) NOT NULL,
  `code` varchar(128) NOT NULL,
  `name` varchar(256) DEFAULT NULL,
  `description` varchar(1024) DEFAULT NULL,
  `sort_seq` int(11) DEFAULT 0 COMMENT '정렬 순서',
  `created_at` timestamp NULL DEFAULT current_timestamp() COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT 0 COMMENT '삭제 상태',
  PRIMARY KEY (`group_code`,`code`),
  CONSTRAINT `cb_common_code_ibfk_1` FOREIGN KEY (`group_code`) REFERENCES `cb_code_group` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='공통코드';

CREATE TABLE `cb_rack_center` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '렉 센터 아이디',
  `uuid` varchar(36) NOT NULL DEFAULT uuid() COMMENT '렉 센터 UUID',
  `name` varchar(127) DEFAULT NULL COMMENT '렉 센터 이름',
  `location` varchar(127) DEFAULT NULL COMMENT '렉 위치',
  `rack_cnt` int(11) DEFAULT NULL COMMENT '렉 센터 내 렉의 수량',
  `status` varchar(36) DEFAULT NULL COMMENT '렉 상태',
  `description` varchar(127) DEFAULT NULL COMMENT '설명',
  `usable` varchar(36) DEFAULT NULL COMMENT '용도',
  `created_at` timestamp NULL DEFAULT NULL COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10049 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='렉 센터';

CREATE TABLE `cb_rack` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '렉 아이디',
  `name` varchar(127) DEFAULT NULL COMMENT '렉 이름',
  `center_id` bigint(20) NOT NULL COMMENT '렉 센터 아이디',
  `size` int(11) DEFAULT NULL COMMENT '렉 내 자원의 수량',
  `available_unit` varchar(10) DEFAULT NULL COMMENT '사용 가능 유닛',
  `using_unit` varchar(10) DEFAULT NULL COMMENT '사용 중인 유닛',
  `disable_unit` varchar(10) DEFAULT NULL COMMENT '비활성화 유닛',
  `usable` varchar(36) DEFAULT NULL COMMENT '용도',
  `floor` varchar(10) DEFAULT NULL COMMENT '층',
  `area` varchar(36) DEFAULT NULL COMMENT '구역',
  `install_date` varchar(36) DEFAULT NULL COMMENT '설치일자',
  `company` varchar(36) DEFAULT NULL COMMENT '제조사',
  `model` varchar(50) DEFAULT NULL COMMENT '모델',
  `series` varchar(36) DEFAULT NULL COMMENT '시리즈',
  `source` varchar(36) DEFAULT NULL COMMENT '출처',
  `price` varchar(36) DEFAULT NULL COMMENT '가격',
  `company_charge` varchar(36) DEFAULT NULL COMMENT '담당업체',
  `manager` varchar(10) DEFAULT NULL COMMENT '담당자',
  `contact` varchar(20) DEFAULT NULL COMMENT '연락처',
  `created_at` timestamp NULL DEFAULT NULL COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  PRIMARY KEY (`id`),
  KEY `FK_rack_center_TO_rack_1` (`center_id`),
  CONSTRAINT `FK_rack_center_TO_rack_1` FOREIGN KEY (`center_id`) REFERENCES `cb_rack_center` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1050 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='렉';

CREATE TABLE `cb_cpu` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'cpu 아이디',
  `resource_id` bigint(20) DEFAULT NULL COMMENT '리소스 아이디',
  `type` varchar(10) DEFAULT NULL COMMENT '타입',
  `cpu_core` bigint(20) DEFAULT NULL COMMENT 'cpu 할당량',
  `hyper_thread` tinyint(1) DEFAULT NULL COMMENT '하이퍼 쓰레드',
  `cpu_allocation_ratio` double DEFAULT NULL COMMENT 'cpu 가상화율',
  `cpu_core_virtual` bigint(20) DEFAULT NULL COMMENT 'cpu 할당량 가상화',
  `created_at` timestamp NULL DEFAULT current_timestamp() COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1178 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='CPU';

CREATE TABLE `cb_disk` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'disk 아이디',
  `resource_id` bigint(20) DEFAULT NULL COMMENT '리소스 아이디',
  `type` varchar(10) DEFAULT NULL COMMENT '타입',
  `disk_total` bigint(20) DEFAULT NULL COMMENT '디스크 할당량',
  `created_at` timestamp NULL DEFAULT current_timestamp() COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  `disk_type` varchar(10) DEFAULT NULL COMMENT '디스크 타입',
  `lvm` varchar(10) DEFAULT NULL COMMENT 'lvm',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=247 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='디스크';

CREATE TABLE `cb_host` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '호스트 아이디',
  `rack_id` bigint(20) NOT NULL COMMENT '렉 아이디',
  `uuid` varchar(36) NOT NULL DEFAULT uuid() COMMENT '호스트 UUID',
  `name` varchar(127) DEFAULT NULL COMMENT '호스트 이름',
  `status` varchar(127) DEFAULT NULL COMMENT '호스트 상태',
  `hostGroupId` varchar(36) DEFAULT NULL COMMENT '호스트 그룹 아이디',
  `asset_registration` varchar(36) DEFAULT NULL COMMENT '자산 등록',
  `install_date` varchar(36) DEFAULT NULL COMMENT '설치 일자',
  `company` varchar(36) DEFAULT NULL COMMENT '제조사',
  `serial_num` varchar(36) DEFAULT NULL COMMENT '시리얼 번호',
  `model` varchar(50) DEFAULT NULL COMMENT '모델 명',
  `os_info` varchar(36) DEFAULT NULL COMMENT '운영 체제',
  `console_info` varchar(50) DEFAULT NULL COMMENT '관리 콘솔 정보',
  `location` varchar(255) DEFAULT NULL COMMENT '위치',
  `hypervisor_host_id` varchar(127) DEFAULT NULL COMMENT '하이퍼바이저 호스트 ID',
  `hypervisor_host_name` varchar(127) DEFAULT NULL COMMENT '하이퍼바이저 호스트 이름',
  `management_ip` varchar(50) DEFAULT NULL,
  `usable` varchar(30) DEFAULT NULL COMMENT '용도',
  `vm_count` int(11) DEFAULT NULL COMMENT 'vm 갯',
  `created_at` timestamp NULL DEFAULT current_timestamp() COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  PRIMARY KEY (`id`),
  KEY `FK_rack_TO_host_1` (`rack_id`),
  CONSTRAINT `FK_rack_TO_host_1` FOREIGN KEY (`rack_id`) REFERENCES `cb_rack` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=98 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='호스트';

CREATE TABLE `cb_host_provider` (
  `host_id` bigint(20) DEFAULT NULL COMMENT '호스트 아이디',
  `provider_id` bigint(20) DEFAULT NULL,
  `provider_uuid` varchar(50) DEFAULT NULL COMMENT 'provider uuid',
  KEY `FK_host_TO_host_provider` (`host_id`),
  CONSTRAINT `FK_host_TO_host_provider` FOREIGN KEY (`host_id`) REFERENCES `cb_host` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='호스트 프로바이더';

CREATE TABLE `cb_nic` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '닉 아이디',
  `host_id` bigint(20) NOT NULL COMMENT '호스트 아이디',
  `name` varchar(127) DEFAULT NULL COMMENT '닉 이름',
  `type` tinyint(1) DEFAULT NULL COMMENT '타입',
  `network_type` varchar(20) DEFAULT NULL COMMENT '네트워크 타입',
  `ip` varchar(40) DEFAULT NULL COMMENT 'ip',
  `mac_addr` varchar(50) DEFAULT NULL COMMENT '맥 주소',
  `created_at` timestamp NULL DEFAULT NULL COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  PRIMARY KEY (`id`),
  KEY `FK_host_TO_nic_1` (`host_id`),
  CONSTRAINT `FK_host_TO_nic_1` FOREIGN KEY (`host_id`) REFERENCES `cb_host` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1290 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='닉';

CREATE TABLE `cb_nic_port` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '닉 포트 아이디',
  `nic_id` bigint(20) NOT NULL COMMENT '닉 아이디',
  `name` varchar(100) DEFAULT NULL,
  `ip` varchar(100) DEFAULT NULL COMMENT 'ip',
  `mac_addr` varchar(100) DEFAULT NULL COMMENT 'mac 주소',
  `created_at` timestamp NULL DEFAULT NULL COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  `description` varchar(100) DEFAULT NULL,
  `type` varchar(100) DEFAULT NULL COMMENT '타입',
  PRIMARY KEY (`id`),
  KEY `FK_nic_TO_nic_port_1` (`nic_id`),
  CONSTRAINT `FK_nic_TO_nic_port_1` FOREIGN KEY (`nic_id`) REFERENCES `cb_nic` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=696 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='닉 포트';

CREATE TABLE `cb_memory` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'memory 아이디',
  `resource_id` bigint(20) DEFAULT NULL COMMENT '리소스 아이디',
  `type` varchar(10) DEFAULT NULL COMMENT '타입',
  `memory_total` bigint(20) DEFAULT NULL COMMENT '메모리 할당량',
  `ram_allocation_ratio` double DEFAULT NULL COMMENT '메모리 가상화율',
  `memory_total_virtual` bigint(20) DEFAULT NULL COMMENT '메모리 할당량 가상화',
  `created_at` timestamp NULL DEFAULT current_timestamp() COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=203 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='memory';

CREATE TABLE `cb_storage` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '스토리지 아이디',
  `rack_id` bigint(20) NOT NULL COMMENT '렉 아이디',
  `uuid` varchar(36) NOT NULL DEFAULT uuid() COMMENT '스토리지 UUID',
  `status` varchar(127) DEFAULT NULL COMMENT '스토리지 상태',
  `name` varchar(127) DEFAULT NULL COMMENT '스토리지 명',
  `asset_registration` varchar(36) DEFAULT NULL COMMENT '자산 등록',
  `install_date` varchar(36) DEFAULT NULL COMMENT '설치 일자',
  `company` varchar(36) DEFAULT NULL COMMENT '제조사',
  `serial_num` varchar(36) DEFAULT NULL COMMENT '시리얼 번호',
  `model` varchar(50) DEFAULT NULL COMMENT '모델 명',
  `snmp_ip` varchar(32) DEFAULT NULL COMMENT '수집용 snmp 아이피',
  `snmp_port` int(11) DEFAULT NULL COMMENT '수집용 snmp 포트',
  `snmp_version` varchar(32) DEFAULT NULL COMMENT '수집용 snmp 버전',
  `snmp_community` varchar(128) DEFAULT NULL COMMENT '수집용 snmp 커뮤니티명',
  `created_at` timestamp NULL DEFAULT current_timestamp() COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  `vm_count` int(11) DEFAULT NULL COMMENT 'vm 갯수',
  `usable` varchar(30) DEFAULT NULL COMMENT '용도',
  PRIMARY KEY (`id`),
  KEY `FK_rack_TO_storage_1` (`rack_id`),
  CONSTRAINT `FK_rack_TO_storage_1` FOREIGN KEY (`rack_id`) REFERENCES `cb_rack` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1014 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='스토리지';

CREATE TABLE `cb_network_vlan` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `provider_id` bigint(20) NOT NULL,
  `name` varchar(500) NOT NULL,
  `status` varchar(100) DEFAULT NULL COMMENT 'ACTIVE, DOWN, BUILD, ERROR',
  `uuid` varchar(200) NOT NULL,
  `tenant_id` varchar(100) DEFAULT NULL,
  `project_id` varchar(100) DEFAULT NULL,
  `provider_network_type` varchar(100) DEFAULT NULL,
  `provider_physical_network` varchar(100) DEFAULT NULL,
  `provider_segmentation_id` int(11) DEFAULT NULL,
  `subnets` varchar(500) DEFAULT NULL,
  `tags` varchar(2000) DEFAULT NULL,
  `revision_number` int(11) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 상태',
  `subnets_cidr` varchar(2048) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `openstack_id` (`provider_id`)
) ENGINE=InnoDB AUTO_INCREMENT=562029 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



CREATE TABLE `cb_openstack_fail_logs` (
  `object_id` varchar(255) NOT NULL,
  `req_id` varchar(100) NOT NULL,
  `object_type` varchar(100) DEFAULT NULL,
  `code` varchar(100) DEFAULT NULL,
  `message` mediumtext DEFAULT NULL,
  `create_at` datetime NOT NULL,
  `details` mediumtext DEFAULT NULL,
  `host` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;





CREATE TABLE `cb_rack_resource_pos` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '렉 리소스 포스 아이디',
  `rack_id` bigint(20) NOT NULL COMMENT '렉 아이디',
  `resource_id` bigint(20) NOT NULL COMMENT '자원 아이디',
  `resource_type` varchar(127) NOT NULL COMMENT '자원 타입',
  `slot_pos` int(11) DEFAULT NULL COMMENT '슬롯 시작 위치',
  `slot_size` int(11) DEFAULT NULL COMMENT '슬롯 사이즈',
  `created_at` timestamp NULL DEFAULT NULL COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  `status` varchar(10) DEFAULT NULL COMMENT '상태',
  `name` varchar(100) DEFAULT NULL COMMENT '이름',
  PRIMARY KEY (`id`),
  KEY `FK_rack_TO_rack_resource_pos_1` (`rack_id`),
  CONSTRAINT `FK_rack_TO_rack_resource_pos_1` FOREIGN KEY (`rack_id`) REFERENCES `cb_rack` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=228 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='렉 자원 위치';

CREATE TABLE `cb_resource_attr` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `resource_type` varchar(10) DEFAULT NULL,
  `resource_id` bigint(20) DEFAULT NULL,
  `key` varchar(100) DEFAULT NULL,
  `value` varchar(100) DEFAULT NULL,
  `value_unit` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1295 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `cb_resource_cfg` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `resource_type` varchar(20) DEFAULT NULL,
  `resource_id` bigint(20) DEFAULT NULL,
  `key` varchar(100) DEFAULT NULL,
  `value` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=821 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='수집용 리소스 별 설정정보';



CREATE TABLE `cb_switch` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '스위치 아이디',
  `rack_id` bigint(20) NOT NULL COMMENT '렉 아이디',
  `uuid` varchar(36) NOT NULL DEFAULT uuid() COMMENT '스위치 UUID',
  `name` varchar(127) DEFAULT NULL COMMENT '스위치 이름',
  `status` varchar(127) DEFAULT NULL COMMENT '스위치 상태',
  `location` varchar(127) DEFAULT NULL COMMENT '스위치 위치',
  `model` varchar(127) DEFAULT NULL COMMENT '스위치 모델 이름',
  `network_usage` varchar(127) DEFAULT NULL COMMENT '스위치 네트워크 사용량',
  `asset_registration` varchar(36) DEFAULT NULL COMMENT '자산 등록',
  `install_date` varchar(36) DEFAULT NULL COMMENT '설치 일자',
  `company` varchar(36) DEFAULT NULL COMMENT '제조사',
  `serial_num` varchar(36) DEFAULT NULL COMMENT '시리얼 번호',
  `port_info` varchar(127) DEFAULT NULL COMMENT '포트구성',
  `usable` varchar(30) DEFAULT NULL COMMENT '용도',
  `group_yn` varchar(127) DEFAULT NULL COMMENT '그룹 여부',
  `group_peer_id` bigint(20) DEFAULT NULL COMMENT '그룹 상대 스위치 아이디',
  `stack_yn` varchar(127) DEFAULT NULL COMMENT '스태킹 여부',
  `stack_type` varchar(127) DEFAULT NULL COMMENT '스태킹 타입',
  `switch_port_filter` varchar(127) DEFAULT NULL COMMENT '스위치 포트 필터',
  `created_at` timestamp NULL DEFAULT current_timestamp() COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  PRIMARY KEY (`id`),
  KEY `FK_rack_TO_switch_1` (`rack_id`),
  CONSTRAINT `FK_rack_TO_switch_1` FOREIGN KEY (`rack_id`) REFERENCES `cb_rack` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1109 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='스위치';

CREATE TABLE `cb_switch_vlan` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `switches_id` bigint(20) NOT NULL COMMENT '스위치 아이디',
  `status` varchar(100) DEFAULT NULL COMMENT 'active, notInService, notReady, createAndGo, createAndWait, destroy',
  `vlan_id` bigint(20) DEFAULT NULL COMMENT '스위치 vlan 아이디',
  `vlan_name` varchar(127) DEFAULT NULL COMMENT '스위치 vlan 이름',
  `created_at` timestamp NULL DEFAULT NULL COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  PRIMARY KEY (`id`),
  KEY `switches_id` (`switches_id`),
  CONSTRAINT `cb_switch_vlan_ibfk_1` FOREIGN KEY (`switches_id`) REFERENCES `cb_switch` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1217 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='스위치 포트';

CREATE TABLE `cb_switch_port` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '스위치 포트 아이디',
  `switches_id` bigint(20) NOT NULL COMMENT '스위치 아이디',
  `switches_id_physical` bigint(20) DEFAULT NULL,
  `port_no` bigint(20) DEFAULT NULL,
  `port_name` varchar(127) DEFAULT NULL,
  `stack` bigint(20) DEFAULT NULL COMMENT '스위치 stack 번호',
  `slot` bigint(20) DEFAULT NULL COMMENT '스위치 slot 번호',
  `port` bigint(20) DEFAULT NULL COMMENT '스위치 port 번호',
  `status` varchar(127) DEFAULT NULL COMMENT '스위치 상태',
  `peer_id` bigint(20) DEFAULT NULL COMMENT '연결 아이디',
  `peer_type` varchar(127) DEFAULT NULL COMMENT '연결 타입',
  `port_ifType` varchar(100) DEFAULT NULL,
  `port_ifMtu` varchar(100) DEFAULT NULL,
  `port_ifHighSpeed` varchar(100) DEFAULT NULL,
  `port_ifPhysAddress` varchar(100) DEFAULT NULL,
  `port_ifAdminStatus` varchar(100) DEFAULT NULL,
  `port_ifLastChange` datetime DEFAULT NULL,
  `port_ifHCInOctets` varchar(100) DEFAULT NULL,
  `port_ifHCInUcastPkts` varchar(100) DEFAULT NULL,
  `port_ifHCInMulticastPkts` varchar(100) DEFAULT NULL,
  `port_ifHCInBroadcastPkts` varchar(100) DEFAULT NULL,
  `port_ifInDiscards` varchar(100) DEFAULT NULL,
  `port_ifInErrors` varchar(100) DEFAULT NULL,
  `port_ifInUnknownProtos` varchar(100) DEFAULT NULL,
  `port_ifHCOutOctets` varchar(100) DEFAULT NULL,
  `port_ifHCOutUcastPkts` varchar(100) DEFAULT NULL,
  `port_ifHCOutMulticastPkts` varchar(100) DEFAULT NULL,
  `port_ifHCOutBroadcastPkts` varchar(100) DEFAULT NULL,
  `port_ifOutDiscards` varchar(100) DEFAULT NULL,
  `port_ifOutErrors` varchar(100) DEFAULT NULL,
  `port_ifOutQLen` varchar(100) DEFAULT NULL,
  `port_ifSpecific` varchar(100) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `deleted` tinyint(1) DEFAULT NULL COMMENT '삭제 상태',
  PRIMARY KEY (`id`),
  KEY `switch_to_switch_port` (`switches_id`),
  CONSTRAINT `switch_to_switch_port` FOREIGN KEY (`switches_id`) REFERENCES `cb_switch` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=31365 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='스위치 포트';


CREATE TABLE `cb_switch_lldp_remote` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'lldp table 아이디',
  `switches_id` bigint(20) NOT NULL COMMENT '스위치 아이디',
  `switch_port_no` bigint(20) NOT NULL COMMENT '스위치 포트 넘버',
  `lldpRemChassisIdSubtype` bigint(20) DEFAULT NULL COMMENT 'lldp chassisIdSubtype',
  `lldpRemChassisId` varchar(127) DEFAULT NULL COMMENT 'lldp ChassisId',
  `lldpRemPortIdSubtype` bigint(20) DEFAULT NULL COMMENT 'lldp PortIdSubtype',
  `lldpRemPortId` varchar(100) DEFAULT NULL COMMENT 'lldp PortId',
  `lldpRemPortDesc` text DEFAULT NULL COMMENT 'lldp RemotePortDesc',
  `lldpRemSysName` varchar(127) DEFAULT NULL COMMENT 'lldp RemotePort system-name',
  `lldpRemSysDesc` text DEFAULT NULL COMMENT 'lldp Remote System-Description',
  `lldpRemSysCapSupported` varchar(127) DEFAULT NULL COMMENT 'lldp Remote System-CapSupported',
  `lldpRemSysCapEnabled` varchar(127) DEFAULT NULL COMMENT 'lldp Remote System-CapEnabled',
  `created_at` timestamp NULL DEFAULT NULL COMMENT '생성 일시',
  `updated_at` timestamp NULL DEFAULT NULL COMMENT '수정 일시',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1411643 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='스위치 lldp';


CREATE TABLE `cb_switch_port_mac_ip` (
  `switch_port_id` bigint(20) NOT NULL,
  `ip_address` varchar(32) NOT NULL,
  `mac_address` varchar(32) NOT NULL,
  PRIMARY KEY (`switch_port_id`,`ip_address`,`mac_address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `cb_switch_port_nic_port` (
  `switch_port_id` bigint(20) NOT NULL COMMENT '스위치 포트 아이디',
  `nic_port_id` bigint(20) NOT NULL COMMENT '닉 포트 아이디',
  `data_type` varchar(1) NOT NULL COMMENT 'A = arp(mac-table) L = (LLDP table)',
  PRIMARY KEY (`switch_port_id`,`nic_port_id`,`data_type`),
  UNIQUE KEY `unique_switch_nic` (`switch_port_id`,`nic_port_id`,`data_type`),
  KEY `fk_nic_port` (`nic_port_id`),
  CONSTRAINT `cb_switch_port_nic_port_cb_nic_port_FK` FOREIGN KEY (`nic_port_id`) REFERENCES `cb_nic_port` (`id`),
  CONSTRAINT `cb_switch_port_nic_port_cb_switch_port_FK` FOREIGN KEY (`switch_port_id`) REFERENCES `cb_switch_port` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='스위치 관리 정보';

CREATE TABLE `cb_switch_port_performance` (
  `switch_port_id` bigint(20) NOT NULL COMMENT '스위치 포트 아이디',
  `switch_port_bandwidth` varchar(100) DEFAULT NULL COMMENT '포트별 대역폭',
  `switch_port_in_bps` varchar(100) DEFAULT NULL COMMENT '포트별 초당 사용량(in)',
  `switch_port_out_bps` varchar(100) DEFAULT NULL COMMENT '포트별 초당 사용량(out)',
  `switch_port_in_usage` varchar(100) DEFAULT NULL COMMENT '포트별 초당 사용률(in)',
  `switch_port_out_usage` varchar(100) DEFAULT NULL COMMENT '포트별 초당 사용률(out)',
  `switch_port_in_ucast_usage` varchar(100) DEFAULT NULL COMMENT '포트별 초당 사용률(유니캐스트 in)',
  `switch_port_in_mcast_usage` varchar(100) DEFAULT NULL COMMENT '포트별 초당 사용률(멀티캐스트 in)',
  `switch_port_in_bcast_usage` varchar(100) DEFAULT NULL COMMENT '포트별 초당 사용률(브로드캐스트 in)',
  `switch_port_out_ucast_usage` varchar(100) DEFAULT NULL COMMENT '포트별 초당 사용률(유니캐스트 out)',
  `switch_port_out_mcast_usage` varchar(100) DEFAULT NULL COMMENT '포트별 초당 사용률(멀티캐스트 out)',
  `switch_port_out_bcast_usage` varchar(100) DEFAULT NULL COMMENT '포트별 초당 사용률(브로드캐스트 out)',
  PRIMARY KEY (`switch_port_id`),
  CONSTRAINT `cb_switch_port_performance_cb_switch_port_FK` FOREIGN KEY (`switch_port_id`) REFERENCES `cb_switch_port` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cb_switch_port_vlan` (
  `switch_port_id` bigint(20) NOT NULL,
  `switch_vlan_id` bigint(20) NOT NULL,
  `switch_port_switches_id_physical` bigint(20) NOT NULL,
  `switch_port_port_no` bigint(20) NOT NULL,
  `switch_vlan_vlan_id` bigint(20) NOT NULL,
  PRIMARY KEY (`switch_port_id`,`switch_vlan_id`),
  KEY `switch_vlan_id` (`switch_vlan_id`),
  CONSTRAINT `cb_switch_port_vlan_ibfk_1` FOREIGN KEY (`switch_port_id`) REFERENCES `cb_switch_port` (`id`),
  CONSTRAINT `cb_switch_port_vlan_ibfk_2` FOREIGN KEY (`switch_vlan_id`) REFERENCES `cb_switch_vlan` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



CREATE TABLE `cb_vm_network_vlan` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `vm_uuid` varchar(200) NOT NULL,
  `provider_id` bigint(20) NOT NULL,
  `network_vlan_uuid` varchar(200) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `network_vlan_uuid` (`network_vlan_uuid`)
) ENGINE=InnoDB AUTO_INCREMENT=16808956 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `nova_instances` (
  `provider_id` varchar(255) NOT NULL,
  `domain` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `id` int(11) NOT NULL,
  `project_id` varchar(255) DEFAULT NULL,
  `user_id` varchar(255) DEFAULT NULL,
  `image_ref` varchar(255) DEFAULT NULL,
  `kernel_id` varchar(255) DEFAULT NULL,
  `ramdisk_id` varchar(255) DEFAULT NULL,
  `launch_index` int(11) DEFAULT NULL,
  `key_name` varchar(255) DEFAULT NULL,
  `key_data` mediumtext DEFAULT NULL,
  `power_state` int(11) DEFAULT NULL,
  `vm_state` varchar(255) DEFAULT NULL,
  `memory_mb` int(11) DEFAULT NULL,
  `vcpus` int(11) DEFAULT NULL,
  `vm_name` varchar(255) DEFAULT NULL,
  `host` varchar(255) DEFAULT NULL,
  `user_data` mediumtext DEFAULT NULL,
  `reservation_id` varchar(255) DEFAULT NULL,
  `launched_at` datetime DEFAULT NULL,
  `terminated_at` datetime DEFAULT NULL,
  `display_name` varchar(255) DEFAULT NULL,
  `display_description` varchar(255) DEFAULT NULL,
  `availability_zone` varchar(255) DEFAULT NULL,
  `locked` tinyint(1) DEFAULT NULL,
  `os_type` varchar(255) DEFAULT NULL,
  `launched_on` mediumtext DEFAULT NULL,
  `instance_type_id` int(11) DEFAULT NULL,
  `vm_mode` varchar(255) DEFAULT NULL,
  `uuid` varchar(36) NOT NULL,
  `architecture` varchar(255) DEFAULT NULL,
  `root_device_name` varchar(255) DEFAULT NULL,
  `access_ip_v4` varchar(39) DEFAULT NULL,
  `access_ip_v6` varchar(39) DEFAULT NULL,
  `config_drive` varchar(255) DEFAULT NULL,
  `task_state` varchar(255) DEFAULT NULL,
  `default_ephemeral_device` varchar(255) DEFAULT NULL,
  `default_swap_device` varchar(255) DEFAULT NULL,
  `progress` int(11) DEFAULT NULL,
  `auto_disk_config` tinyint(1) DEFAULT NULL,
  `shutdown_terminate` tinyint(1) DEFAULT NULL,
  `disable_terminate` tinyint(1) DEFAULT NULL,
  `root_gb` int(11) DEFAULT NULL,
  `ephemeral_gb` int(11) DEFAULT NULL,
  `cell_name` varchar(255) DEFAULT NULL,
  `node` varchar(255) DEFAULT NULL,
  `deleted` int(11) DEFAULT NULL,
  `locked_by` enum('owner','admin') DEFAULT NULL,
  `cleaned` int(11) DEFAULT NULL,
  `ephemeral_key_uuid` varchar(36) DEFAULT NULL,
  `hidden` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_nova_instances0uuid` (`uuid`),
  KEY `nova_instances_deleted_created_at_idx` (`deleted`,`created_at`),
  KEY `nova_instances_terminated_at_launched_at_idx` (`terminated_at`,`launched_at`),
  KEY `nova_instances_host_node_deleted_idx` (`host`,`node`,`deleted`),
  KEY `nova_instances_host_deleted_cleaned_idx` (`host`,`deleted`,`cleaned`),
  KEY `nova_instances_project_id_deleted_idx` (`project_id`,`deleted`),
  KEY `nova_instances_uuid_deleted_idx` (`uuid`,`deleted`),
  KEY `nova_instances_project_id_idx` (`project_id`),
  KEY `nova_instances_task_state_updated_at_idx` (`task_state`,`updated_at`),
  KEY `nova_instances_reservation_id_idx` (`reservation_id`),
  KEY `nova_instances_updated_at_project_id_idx` (`updated_at`,`project_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

CREATE TABLE `keystone_users` (
  `id` char(36) NOT NULL,
  `email` varchar(100) NOT NULL,
  `name` varchar(100) NOT NULL,
  `password` varchar(100) NOT NULL,
  `username` varchar(100) NOT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_users_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `glance_images` (
  `id` char(36) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT 0,
  `name` varchar(250) NOT NULL,
  `owner_id` char(36) NOT NULL,
  `size` bigint(20) NOT NULL,
  `filename` varchar(150) DEFAULT NULL,
  `savename` varchar(165) DEFAULT NULL,
  `isimage` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `fk_image_users` (`owner_id`),
  CONSTRAINT `fk_image_users` FOREIGN KEY (`owner_id`) REFERENCES `keystone_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `glance_image_tags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `value` varchar(100) NOT NULL,
  `image_id` char(36) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `fk_image_tags_image` (`image_id`),
  CONSTRAINT `fk_image_tags_image` FOREIGN KEY (`image_id`) REFERENCES `glance_images` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `nova_api_flavors` (
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `id` int(11) NOT NULL,
  `memory_mb` int(11) NOT NULL,
  `vcpus` int(11) NOT NULL,
  `swap` int(11) NOT NULL,
  `vcpu_weight` int(11) DEFAULT NULL,
  `flavorid` varchar(255) NOT NULL,
  `rxtx_factor` float DEFAULT NULL,
  `root_gb` int(11) DEFAULT NULL,
  `ephemeral_gb` int(11) DEFAULT NULL,
  `disabled` tinyint(1) DEFAULT NULL,
  `is_public` tinyint(1) DEFAULT NULL,
  `description` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_nova_flavors0flavorid` (`flavorid`),
  UNIQUE KEY `uniq_nova_flavors0name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

CREATE TABLE `nova_block_device_mapping` (
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `id` int(11) NOT NULL,
  `device_name` varchar(255) DEFAULT NULL,
  `delete_on_termination` tinyint(1) DEFAULT NULL,
  `snapshot_id` varchar(36) DEFAULT NULL,
  `volume_id` varchar(36) DEFAULT NULL,
  `volume_size` int(11) DEFAULT NULL,
  `no_device` tinyint(1) DEFAULT NULL,
  `connection_info` mediumtext DEFAULT NULL,
  `instance_uuid` varchar(36) DEFAULT NULL,
  `deleted` int(11) DEFAULT NULL,
  `source_type` varchar(255) DEFAULT NULL,
  `destination_type` varchar(255) DEFAULT NULL,
  `guest_format` varchar(255) DEFAULT NULL,
  `device_type` varchar(255) DEFAULT NULL,
  `disk_bus` varchar(255) DEFAULT NULL,
  `boot_index` int(11) DEFAULT NULL,
  `image_id` varchar(36) DEFAULT NULL,
  `tag` varchar(255) DEFAULT NULL,
  `attachment_id` varchar(36) DEFAULT NULL,
  `uuid` varchar(36) DEFAULT NULL,
  `volume_type` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_nova_block_device_mapping0uuid` (`uuid`),
  KEY `nova_block_device_mapping_instance_uuid_idx` (`instance_uuid`),
  KEY `snapshot_id` (`snapshot_id`),
  KEY `nova_block_device_mapping_instance_uuid_device_name_idx` (`instance_uuid`,`device_name`),
  KEY `volume_id` (`volume_id`),
  KEY `nova_block_device_mapping_instance_uuid_volume_id_idx` (`instance_uuid`,`volume_id`),
  CONSTRAINT `nova_block_device_mapping_instance_uuid_fkey` FOREIGN KEY (`instance_uuid`) REFERENCES `nova_instances` (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

CREATE TABLE `nova_instance_info_caches` (
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `network_info` mediumtext DEFAULT NULL,
  `instance_uuid` varchar(36) NOT NULL,
  `deleted` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_nova_instance_info_caches0instance_uuid` (`instance_uuid`),
  CONSTRAINT `nova_instance_info_caches_instance_uuid_fkey` FOREIGN KEY (`instance_uuid`) REFERENCES `nova_instances` (`uuid`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;



