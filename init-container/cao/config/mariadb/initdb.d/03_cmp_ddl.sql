CREATE DATABASE IF NOT EXISTS `maestro` ;

USE `maestro`;

-- maestro.MSTR_ACCESS_CONTROL definition

CREATE OR REPLACE TABLE `MSTR_ACCESS_CONTROL` (
  `id` varchar(36) NOT NULL DEFAULT uuid() COMMENT '고유 식별자 ID',
  `ip_address` varchar(15) NOT NULL COMMENT 'IP Address',
  `cidr` tinyint(4) NOT NULL COMMENT 'CIDR - Prefix Length',
  `description` text DEFAULT NULL COMMENT '설명',
  `status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '상태',
  `create_user_id` varchar(36) NOT NULL COMMENT '생성자 ID',
  `create_time` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '생성일시',
  `update_user_id` varchar(36) DEFAULT NULL COMMENT '수정자 ID',
  `update_time` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT '수정일시',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='접근 제어';


-- maestro.MSTR_ASSIGNER_IN_WORKFLOW definition

CREATE OR REPLACE TABLE `MSTR_ASSIGNER_IN_WORKFLOW` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `assign_user_id` varchar(36) DEFAULT NULL,
  `workflow_id` varchar(36) NOT NULL,
  `assign_type` int(11) DEFAULT 1,
  `create_time` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_AUTHORITY definition

CREATE OR REPLACE TABLE `MSTR_AUTHORITY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `description` text DEFAULT NULL,
  `selector` text DEFAULT NULL,
  `type` varchar(127) DEFAULT NULL,
  `category` varchar(127) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `solution` varchar(127) DEFAULT NULL,
  `constant` tinyint(4) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `MSTR_AUTHORITY_create_time_index` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_AUTHORITY_TYPE definition

CREATE OR REPLACE TABLE `MSTR_AUTHORITY_TYPE` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `description` varchar(255) DEFAULT NULL,
  `is_default` int(11) DEFAULT 0,
  `name` varchar(255) DEFAULT NULL,
  `selector` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_BOARD definition

CREATE OR REPLACE TABLE `MSTR_BOARD` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(500) DEFAULT NULL,
  `data` text DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 1,
  `sub_category_id` varchar(36) NOT NULL,
  `pin` tinyint(1) DEFAULT 0,
  `pin_time` timestamp NULL DEFAULT NULL,
  `first_posted_time` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_BOARD_CATEGORY definition

CREATE OR REPLACE TABLE `MSTR_BOARD_CATEGORY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(500) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `MSTR_BOARD_CATEGORY_name_uindex` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_BOARD_FILE definition

CREATE OR REPLACE TABLE `MSTR_BOARD_FILE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(500) DEFAULT NULL,
  `path` varchar(1000) DEFAULT NULL,
  `status` int(11) DEFAULT 1,
  `board_id` varchar(36) NOT NULL DEFAULT uuid(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_BOARD_IN_MSTR_ORG definition

CREATE OR REPLACE TABLE `MSTR_BOARD_IN_MSTR_ORG` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `org_id` varchar(36) NOT NULL DEFAULT uuid(),
  `board_id` varchar(36) NOT NULL DEFAULT uuid(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_BOARD_SUB_CATEGORY definition

CREATE OR REPLACE TABLE `MSTR_BOARD_SUB_CATEGORY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(500) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 1,
  `category_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_CATEGORY definition

CREATE OR REPLACE TABLE `MSTR_CATEGORY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ENDPOINT definition

CREATE OR REPLACE TABLE `MSTR_ENDPOINT` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(500) DEFAULT NULL,
  `description` varchar(2000) DEFAULT NULL,
  `uri` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_bin DEFAULT NULL,
  `solution_id` varchar(36) NOT NULL,
  `solution` varchar(127) DEFAULT NULL,
  `service` varchar(127) DEFAULT NULL,
  `type` varchar(127) DEFAULT NULL,
  `method` varchar(127) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `solution_server_id` varchar(255) DEFAULT NULL,
  `white_api` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `MSTR_ENDPOINT_pk` (`uri`,`method`,`solution_server_id`),
  KEY `MSTR_ENDPOINT_create_time_index` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ENDPOINT_RESOURCE_TYPE definition

CREATE OR REPLACE TABLE `MSTR_ENDPOINT_RESOURCE_TYPE` (
  `name` varchar(127) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `selector` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ENDPOINT_SERVICE definition

CREATE OR REPLACE TABLE `MSTR_ENDPOINT_SERVICE` (
  `name` varchar(127) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `selector` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ENDPOINT_SYNC_LOG definition

CREATE OR REPLACE TABLE `MSTR_ENDPOINT_SYNC_LOG` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sync_time` timestamp NULL DEFAULT NULL,
  `solution` varchar(255) DEFAULT NULL,
  `user_id` varchar(255) DEFAULT NULL,
  `endpoint_sync_log` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `endpoint_event_sync_log` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=91 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ENDPOINT_TYPE_IN_SERVICE definition

CREATE OR REPLACE TABLE `MSTR_ENDPOINT_TYPE_IN_SERVICE` (
  `service` varchar(127) NOT NULL,
  `type` varchar(127) NOT NULL,
  PRIMARY KEY (`service`,`type`),
  KEY `FK_MSTR_ENDPOINT_RESOURC` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_FIELD_IN_SECTION definition

CREATE OR REPLACE TABLE `MSTR_FIELD_IN_SECTION` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `section_id` varchar(36) NOT NULL DEFAULT uuid(),
  `order` int(11) DEFAULT NULL,
  `type_of_field_id` varchar(36) NOT NULL DEFAULT uuid()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

-- maestro.MSTR_FINOPS_COST definition

CREATE OR REPLACE TABLE `MSTR_FINOPS_COST` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `provider_id` varchar(36) DEFAULT NULL,
  `platform_type` varchar(36) DEFAULT NULL,
  `service_type` varchar(36) DEFAULT NULL,
  `instance_no` varchar(100) DEFAULT NULL,
  `instance_name` varchar(36) DEFAULT NULL,
  `instance_type` varchar(36) DEFAULT NULL,
  `status` varchar(36) DEFAULT NULL,
  `sequence` varchar(36) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `use_date` varchar(6) DEFAULT NULL,
  `cost` bigint(20) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_FINOPS_OPENSTACK_MONTH_COST definition

CREATE OR REPLACE TABLE `MSTR_FINOPS_OPENSTACK_MONTH_COST` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `provider_id` varchar(36) DEFAULT NULL COMMENT '공급자 ID',
  `service_type` varchar(36) DEFAULT NULL COMMENT '서비스 유형(VOLUME, NETWORK, INSTANCE)',
  `instance_no` varchar(100) DEFAULT NULL COMMENT '인스턴스 번호',
  `instance_name` varchar(100) DEFAULT NULL COMMENT '인스턴스 이름',
  `description` varchar(100) DEFAULT NULL COMMENT '설명',
  `use_date` varchar(8) DEFAULT NULL COMMENT '사용일시(YYYYMM)',
  `cost` bigint(20) DEFAULT NULL COMMENT '비용',
  `create_time` timestamp NULL DEFAULT NULL COMMENT '생성일시',
  `cost_type` varchar(10) DEFAULT NULL COMMENT '비용 유형(USAGE[사용량], ALLOCATION[할당량])',
  PRIMARY KEY (`id`),
  KEY `idx_id` (`id`),
  KEY `idx_instance_no` (`instance_no`),
  KEY `idx_use_date` (`use_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

-- maestro.MSTR_FOLDER definition

CREATE OR REPLACE TABLE `MSTR_FOLDER` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `description` text DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `parent_id` varchar(36) DEFAULT NULL,
  `org_id` varchar(36) DEFAULT NULL,
  `depth` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `MSTR_FOLDER_create_time_index` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_FOLDER_IN_SERVICE_CATALOG definition

CREATE OR REPLACE TABLE `MSTR_FOLDER_IN_SERVICE_CATALOG` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `folder_id` varchar(36) NOT NULL,
  `service_catalog_id` varchar(36) NOT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_GLOBAL_MENU_AUTHORITY definition

CREATE OR REPLACE TABLE `MSTR_GLOBAL_MENU_AUTHORITY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `global_menu_id` varchar(36) NOT NULL DEFAULT uuid(),
  `authority_id` varchar(36) NOT NULL DEFAULT uuid(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_GLOBAL_OPTION definition

CREATE OR REPLACE TABLE `MSTR_GLOBAL_OPTION` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `name` varchar(255) NOT NULL,
  `value` varchar(255) NOT NULL,
  `use_yn` char(1) NOT NULL DEFAULT 'Y',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_LOG_TAG definition

CREATE OR REPLACE TABLE `MSTR_LOG_TAG` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `description` varchar(2000) DEFAULT NULL,
  `name` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_LOG_TAG_API_DATA definition

CREATE OR REPLACE TABLE `MSTR_LOG_TAG_API_DATA` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `solution` varchar(255) DEFAULT NULL,
  `log_tag_name` varchar(255) DEFAULT NULL,
  `method` varchar(255) DEFAULT NULL,
  `server_name` varchar(255) DEFAULT NULL,
  `path` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='로그태그 최초 세팅용 데이터. 환경별로 api id가 다를 수 있기 때문에 사용한다.';


-- maestro.MSTR_MENU_FEATURE_TYPE definition

CREATE OR REPLACE TABLE `MSTR_MENU_FEATURE_TYPE` (
  `name` varchar(500) NOT NULL,
  `description` varchar(2000) DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_MENU_PLATFORM definition

CREATE OR REPLACE TABLE `MSTR_MENU_PLATFORM` (
  `menu_id` varchar(255) NOT NULL,
  `platform_id` varchar(255) NOT NULL,
  PRIMARY KEY (`menu_id`,`platform_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `name` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `channel` varchar(255) DEFAULT NULL,
  `repeat_type` varchar(255) DEFAULT NULL,
  `repeat_frequency` varchar(255) DEFAULT NULL,
  `repeat_period` varchar(255) DEFAULT NULL,
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT NULL,
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(255) DEFAULT 'Y',
  `type` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_COMMON_CODE_TYPE definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_COMMON_CODE_TYPE` (
  `code_type_id` varchar(255) NOT NULL,
  `code_type_name` varchar(255) DEFAULT NULL,
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT NULL,
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(255) DEFAULT 'Y',
  PRIMARY KEY (`code_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_DATA definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_DATA` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `event_history_id` varchar(255) DEFAULT NULL,
  `action_yn` varchar(255) DEFAULT NULL,
  `message` varchar(255) DEFAULT NULL,
  `detail_url` varchar(255) DEFAULT NULL,
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT NULL,
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(255) DEFAULT 'Y',
  `level` varchar(255) DEFAULT NULL,
  `user_detail_url` varchar(255) DEFAULT NULL,
  `admin_detail_url` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_DOMAIN_OPTION definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_DOMAIN_OPTION` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `name` varchar(255) DEFAULT NULL,
  `base_path` varchar(255) DEFAULT NULL,
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT NULL,
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(255) DEFAULT 'Y',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_EVENT_CODE definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_EVENT_CODE` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `event_code` varchar(255) DEFAULT NULL,
  `message_form` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `event_condition` varchar(255) DEFAULT NULL,
  `repeat_yn` varchar(255) DEFAULT NULL,
  `level` varchar(255) DEFAULT NULL,
  `attribute` varchar(255) DEFAULT NULL,
  `target` varchar(255) DEFAULT NULL,
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT NULL,
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(255) DEFAULT 'Y',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_EVENT_HISTORY definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_EVENT_HISTORY` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `event_id` varchar(255) DEFAULT NULL,
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT NULL,
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(255) DEFAULT 'Y',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_PERSONAL_RECEIVE definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_PERSONAL_RECEIVE` (
  `id` varchar(100) NOT NULL DEFAULT uuid(),
  `notification_data_id` varchar(100) DEFAULT NULL,
  `read_yn` varchar(255) DEFAULT 'N',
  `user_id` varchar(100) DEFAULT NULL,
  `channel` varchar(100) DEFAULT NULL,
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT current_timestamp(),
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(100) DEFAULT 'Y',
  PRIMARY KEY (`id`),
  KEY `IDX_ID_USER_ID_READ_YN_CHANNEL_NOTIFICATION_DATA_ID` (`id`,`notification_data_id`,`user_id`,`read_yn`,`channel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_RECEIVE_GROUP definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_RECEIVE_GROUP` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `name` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT NULL,
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(255) DEFAULT 'Y',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_RECEIVE_INFO definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_RECEIVE_INFO` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `user_id` varchar(255) DEFAULT NULL,
  `channel` varchar(255) DEFAULT NULL,
  `receive_day` varchar(255) DEFAULT NULL,
  `start_time` int(11) DEFAULT NULL,
  `end_time` int(11) DEFAULT NULL,
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT NULL,
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(255) DEFAULT 'Y',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ORG_IN_SERVICE_OBJECT definition

CREATE OR REPLACE TABLE `MSTR_ORG_IN_SERVICE_OBJECT` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `org_id` varchar(36) DEFAULT NULL,
  `service_object_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ORG_IN_SERVICE_TYPE definition

CREATE OR REPLACE TABLE `MSTR_ORG_IN_SERVICE_TYPE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `org_id` varchar(36) DEFAULT NULL,
  `service_type_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;



-- maestro.MSTR_OTHER_BILLING_POLICY_LOG definition

CREATE OR REPLACE TABLE `MSTR_OTHER_BILLING_POLICY_LOG` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `other_billing_policy_id` varchar(36) NOT NULL DEFAULT uuid(),
  `other_billing_folder_id` varchar(36) NOT NULL,
  `create_user_id` varchar(100) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  `update_contents` varchar(100) DEFAULT NULL,
  `before_modification` varchar(500) DEFAULT NULL,
  `after_modification` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_PROVIDER_NAVIGATOR definition

CREATE OR REPLACE TABLE `MSTR_PROVIDER_NAVIGATOR` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `user_id` varchar(36) NOT NULL COMMENT '사용자 아이디',
  `global_menu_id` varchar(36) NOT NULL COMMENT 'MSTR_PLATFORM 에 있는 id 일치',
  `provider_id` varchar(255) DEFAULT NULL COMMENT 'MSTR_PROVIDER 에 있는 id와 일치',
  `provider_sub` varchar(255) DEFAULT NULL COMMENT '각 플랫폼/솔루션 별로 상이함',
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`,`global_menu_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='공급자 네비게이터 - 공급자 선택 관리';


-- maestro.MSTR_PROVIDER_NAVIGATOR_BOOKMARK definition

CREATE OR REPLACE TABLE `MSTR_PROVIDER_NAVIGATOR_BOOKMARK` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `user_id` varchar(36) NOT NULL COMMENT '사용자 아이디',
  `global_menu_id` varchar(36) NOT NULL COMMENT 'MSTR_PLATFORM 에 있는 id 일치',
  `provider_id` varchar(255) DEFAULT NULL COMMENT 'MSTR_PROVIDER 에 있는 id와 일치',
  `provider_sub` varchar(255) DEFAULT NULL COMMENT '각 플랫폼/솔루션 별로 상이함',
  PRIMARY KEY (`id`),
  UNIQUE KEY `bookmark_uk` (`user_id`,`provider_id`,`provider_sub`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='공급자 네비게이터 북마크  - 공급자 선택 관리';


-- maestro.MSTR_PROVIDER_TYPE definition

CREATE OR REPLACE TABLE `MSTR_PROVIDER_TYPE` (
  `id` int(11) NOT NULL,
  `name` varchar(127) DEFAULT NULL,
  `public` int(11) DEFAULT 1,
  `description` varchar(127) DEFAULT NULL,
  `is_active` int(11) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_REQUEST_BOARD definition

CREATE OR REPLACE TABLE `MSTR_REQUEST_BOARD` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(500) DEFAULT NULL,
  `request_data` text DEFAULT NULL,
  `response_data` text DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `complete_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 1,
  `category` int(11) DEFAULT 1,
  `category_id` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_REQUEST_BOARD_CATEGORY definition

CREATE OR REPLACE TABLE `MSTR_REQUEST_BOARD_CATEGORY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(30) DEFAULT NULL,
  `code` varchar(10) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT 'admin',
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  `is_active` tinyint(1) DEFAULT 1,
  `portal` varchar(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_REQUEST_BOARD_FILE definition

CREATE OR REPLACE TABLE `MSTR_REQUEST_BOARD_FILE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(500) DEFAULT NULL,
  `path` varchar(1000) DEFAULT NULL,
  `status` int(11) DEFAULT 1,
  `board_id` varchar(36) NOT NULL DEFAULT uuid(),
  `type` int(11) DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_REQUEST_OF_SERVICE definition

CREATE OR REPLACE TABLE `MSTR_REQUEST_OF_SERVICE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `assign_user_id` varchar(36) DEFAULT NULL,
  `expect_complete_time` timestamp NULL DEFAULT NULL,
  `content` text DEFAULT NULL,
  `template_request_of_service_id` varchar(36) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_REQUEST_OF_SERVICE_CATEGORY definition

CREATE OR REPLACE TABLE `MSTR_REQUEST_OF_SERVICE_CATEGORY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `description` text DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `type` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_REQUEST_OF_SERVICE_TYPE_BOOKMARK definition

CREATE OR REPLACE TABLE `MSTR_REQUEST_OF_SERVICE_TYPE_BOOKMARK` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `user_id` varchar(36) NOT NULL COMMENT '사용자 아이디',
  `service_type_id` varchar(36) NOT NULL COMMENT 'MSTR_REQUEST_OF_SERVICE_TYPE 에 있는 id 일치',
  `description` text DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='서비스 신청 타입 즐겨찾기 관리';


-- maestro.MSTR_REQUEST_OF_SERVICE_TYPE_IN_FOLDER definition

CREATE OR REPLACE TABLE `MSTR_REQUEST_OF_SERVICE_TYPE_IN_FOLDER` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `uuid` varchar(36) NOT NULL DEFAULT uuid(),
  `service_type_id` varchar(36) DEFAULT NULL,
  `folder_id` varchar(36) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_RESOURCE_TYPE definition

CREATE OR REPLACE TABLE `MSTR_RESOURCE_TYPE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(31) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ROLE_TYPE definition

CREATE OR REPLACE TABLE `MSTR_ROLE_TYPE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `description` varchar(255) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `selector` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SECTION_IN_TEMPLATE_REQUEST_OF_SERVICE definition

CREATE OR REPLACE TABLE `MSTR_SECTION_IN_TEMPLATE_REQUEST_OF_SERVICE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `template_request_of_service_id` varchar(36) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SELECT_FIELD definition

CREATE OR REPLACE TABLE `MSTR_SELECT_FIELD` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SERVICE_CATALOG definition

CREATE OR REPLACE TABLE `MSTR_SERVICE_CATALOG` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SERVICE_OBJECT definition

CREATE OR REPLACE TABLE `MSTR_SERVICE_OBJECT` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `file_path` varchar(255) DEFAULT NULL,
  `image_path` varchar(255) NOT NULL DEFAULT 'https://placeimg.com/100/100/any',
  `platform_id` varchar(36) NOT NULL DEFAULT uuid(),
  `type_of_service_object_build_id` varchar(36) DEFAULT NULL,
  `type_of_service_object_id` varchar(36) DEFAULT NULL,
  `category_id` varchar(36) NOT NULL,
  `yaml` text DEFAULT NULL,
  `use_count` int(11) DEFAULT 0,
  `type` varchar(127) DEFAULT NULL,
  `readme` longtext DEFAULT NULL,
  `chart_name` varchar(255) DEFAULT NULL,
  `chart_version` varchar(255) DEFAULT NULL,
  `helm_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SERVICE_OBJECT_APPROVER definition

CREATE OR REPLACE TABLE `MSTR_SERVICE_OBJECT_APPROVER` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `user_id` varchar(36) DEFAULT NULL,
  `org_id` varchar(36) DEFAULT NULL,
  `step` int(11) DEFAULT 1,
  `service_object_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SERVICE_OBJECT_IN_SERVICE_CATALOG definition

CREATE OR REPLACE TABLE `MSTR_SERVICE_OBJECT_IN_SERVICE_CATALOG` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `service_catalog_id` varchar(36) NOT NULL,
  `service_object_id` varchar(36) NOT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  `create_user_id` varchar(36) DEFAULT NULL,
  UNIQUE KEY `SERVICE_CATALOG_ID_SERVICE_OBJECT_ID` (`service_catalog_id`,`service_object_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SERVICE_OBJECT_IN_SERVICE_CATALOG_BOOKMARK definition

CREATE OR REPLACE TABLE `MSTR_SERVICE_OBJECT_IN_SERVICE_CATALOG_BOOKMARK` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `user_id` varchar(36) NOT NULL COMMENT '사용자 아이디',
  `service_catalog_id` varchar(36) NOT NULL COMMENT 'MSTR_SERVICE_OBJECT_IN_SERVICE_CATALOG 에 있는 service_catalog_id 일치',
  `service_object_id` varchar(36) NOT NULL COMMENT 'MSTR_SERVICE_OBJECT_IN_SERVICE_CATALOG 에 있는 service_object_id 일치',
  `description` text DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='서비스 카탈로그의 서비스 오브젝트 즐겨찾기 관리';


-- maestro.MSTR_SERVICE_REQUEST definition

CREATE OR REPLACE TABLE `MSTR_SERVICE_REQUEST` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `create_time` timestamp NULL DEFAULT NULL,
  `end_time` timestamp NULL DEFAULT NULL,
  `requester_id` varchar(36) NOT NULL,
  `manager_id` varchar(36) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `cidr` varchar(127) DEFAULT NULL,
  `solution_id` varchar(36) NOT NULL,
  `resource_type_id` varchar(36) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SERVICE_REQUEST_COMMENT definition

CREATE OR REPLACE TABLE `MSTR_SERVICE_REQUEST_COMMENT` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `content` text DEFAULT NULL,
  `parent_id` varchar(36) DEFAULT NULL,
  `service_request_id` varchar(36) DEFAULT NULL,
  `depth` int(11) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `deleted` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SERVICE_REQUEST_LOG definition

CREATE OR REPLACE TABLE `MSTR_SERVICE_REQUEST_LOG` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `message` text DEFAULT NULL,
  `service_request_status` int(11) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  `request_of_service_object_id` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sr_log_request_of_service_object_id` (`request_of_service_object_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SERVICE_REQUEST_RESERVATION definition

CREATE OR REPLACE TABLE `MSTR_SERVICE_REQUEST_RESERVATION` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `resource_id` varchar(36) DEFAULT NULL,
  `workspace_id` varchar(36) DEFAULT NULL,
  `request_of_service_object_id` varchar(36) DEFAULT NULL,
  `start_time` timestamp NULL DEFAULT NULL,
  `end_time` timestamp NULL DEFAULT NULL,
  `status` varchar(30) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SERVICE_TYPE_APPROVER definition

CREATE OR REPLACE TABLE `MSTR_SERVICE_TYPE_APPROVER` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `user_id` varchar(36) DEFAULT NULL,
  `org_id` varchar(36) DEFAULT NULL,
  `step` int(11) DEFAULT 0,
  `service_type_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SOLUTION definition

CREATE OR REPLACE TABLE `MSTR_SOLUTION` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` datetime DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` datetime DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `status` int(11) DEFAULT NULL,
  `external_yn` int(11) DEFAULT 0,
  `base_user_path` varchar(255) DEFAULT NULL,
  `base_admin_path` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SOLUTION_IN_WORKSPACE definition

CREATE OR REPLACE TABLE `MSTR_SOLUTION_IN_WORKSPACE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `workspace_id` varchar(36) NOT NULL,
  `solution_id` varchar(36) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_SYMPHONY_ALARM_ENV definition

CREATE OR REPLACE TABLE `MSTR_SYMPHONY_ALARM_ENV` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `date_type` varchar(255) DEFAULT NULL COMMENT '알람 일자 타입, DAY / WEEK',
  `abnormal_limit` int(11) DEFAULT NULL COMMENT '이상 발생 빈도 임계치 ',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='마에스트로 심포니 알람 환경변수 테이블';


-- maestro.MSTR_SYMPHONY_ENV definition

CREATE OR REPLACE TABLE `MSTR_SYMPHONY_ENV` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `platform_type` varchar(255) DEFAULT NULL COMMENT '플랫폼 타입 ex. OPENSTACK, NCP',
  `provider_type_id` int(11) DEFAULT NULL COMMENT 'bt_provider 테이블 참고',
  `resource_type_id` int(11) DEFAULT NULL COMMENT 'bt_provider_type 테이블 참고',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='마에스트로 심포니 연동용 환경변수 테이블';


-- maestro.MSTR_TAG definition

CREATE OR REPLACE TABLE `MSTR_TAG` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_TAG_IN_SERVICE_OBJECT definition

CREATE OR REPLACE TABLE `MSTR_TAG_IN_SERVICE_OBJECT` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `service_object_id` varchar(36) NOT NULL,
  `tag_id` varchar(36) NOT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_TEMPLATE_REQUEST_OF_SERVICE definition

CREATE OR REPLACE TABLE `MSTR_TEMPLATE_REQUEST_OF_SERVICE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_TEXT_FIELD definition

CREATE OR REPLACE TABLE `MSTR_TEXT_FIELD` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_TYPE_OF_FIELD definition

CREATE OR REPLACE TABLE `MSTR_TYPE_OF_FIELD` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `order` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_TYPE_OF_SERVICE_OBJECT definition

CREATE OR REPLACE TABLE `MSTR_TYPE_OF_SERVICE_OBJECT` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_TYPE_OF_SERVICE_OBJECT_BUILD definition

CREATE OR REPLACE TABLE `MSTR_TYPE_OF_SERVICE_OBJECT_BUILD` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_USER_GROUP definition

CREATE OR REPLACE TABLE `MSTR_USER_GROUP` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `description` text DEFAULT NULL,
  `org_id` varchar(36) NOT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 1,
  `group_email` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `MSTR_USER_GROUP_create_time_index` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_USER_ORG_MAPPING definition

CREATE OR REPLACE TABLE `MSTR_USER_ORG_MAPPING` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `user_id` varchar(36) DEFAULT NULL,
  `org_id` varchar(36) DEFAULT NULL,
  `mapping_status` varchar(30) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_user_org` (`user_id`,`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_USER_SERVICE_REQUEST_VIEW_HISTORY definition

CREATE OR REPLACE TABLE `MSTR_USER_SERVICE_REQUEST_VIEW_HISTORY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `user_id` varchar(36) DEFAULT NULL,
  `service_request_id` varchar(36) DEFAULT NULL,
  `last_view_time` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_WORKFLOW definition

CREATE OR REPLACE TABLE `MSTR_WORKFLOW` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `status` int(11) DEFAULT 0,
  `next_workflow_id` varchar(36) DEFAULT NULL,
  `step` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_WORKFLOW_IN_REQUEST_OF_SERVICE_OBJECT definition

CREATE OR REPLACE TABLE `MSTR_WORKFLOW_IN_REQUEST_OF_SERVICE_OBJECT` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `request_of_service_object_id` varchar(36) NOT NULL,
  `workflow_id` varchar(36) NOT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_WORKFLOW_IN_REQUEST_OF_SERVICE_TYPE definition

CREATE OR REPLACE TABLE `MSTR_WORKFLOW_IN_REQUEST_OF_SERVICE_TYPE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `request_of_service_type_id` varchar(36) NOT NULL,
  `workflow_id` varchar(36) NOT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_WORKSPACE definition

CREATE OR REPLACE TABLE `MSTR_WORKSPACE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `description` text DEFAULT NULL,
  `folder_id` varchar(36) NOT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `org_id` varchar(36) DEFAULT NULL,
  `cicd_project_name` varchar(500) DEFAULT NULL,
  `bookmark` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `MSTR_WORKSPACE__org_id__name` (`org_id`,`name`),
  KEY `MSTR_WORKSPACE_create_time_index` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_WORKSPACE_BOOKMARK definition

CREATE OR REPLACE TABLE `MSTR_WORKSPACE_BOOKMARK` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `user_id` varchar(36) NOT NULL COMMENT '사용자 아이디',
  `workspace_id` varchar(36) NOT NULL COMMENT 'MSTR_WORKSPACE 에 있는 id 일치',
  `workspace_name` varchar(36) NOT NULL COMMENT 'MSTR_WORKSPACE 에 있는 name 일치',
  `description` text DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='워크스페이스 즐겨찾기 관리';


-- maestro.QRTZ_CALENDARS definition

CREATE OR REPLACE TABLE `QRTZ_CALENDARS` (
  `SCHED_NAME` varchar(120) NOT NULL COMMENT '스케줄러 이름',
  `CALENDAR_NAME` varchar(200) NOT NULL COMMENT '캘린더 이름',
  `CALENDAR` blob NOT NULL COMMENT '캘린더 데이터',
  PRIMARY KEY (`SCHED_NAME`,`CALENDAR_NAME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Quartz 캘린더 정보';


-- maestro.QRTZ_FIRED_TRIGGERS definition

CREATE OR REPLACE TABLE `QRTZ_FIRED_TRIGGERS` (
  `SCHED_NAME` varchar(120) NOT NULL COMMENT '스케줄러 이름',
  `ENTRY_ID` varchar(95) NOT NULL COMMENT '엔트리 ID',
  `TRIGGER_NAME` varchar(200) NOT NULL COMMENT '트리거 이름',
  `TRIGGER_GROUP` varchar(200) NOT NULL COMMENT '트리거 그룹',
  `INSTANCE_NAME` varchar(200) NOT NULL COMMENT '인스턴스 이름',
  `FIRED_TIME` bigint(13) NOT NULL COMMENT '실행 시간',
  `SCHED_TIME` bigint(13) NOT NULL COMMENT '스케줄 시간',
  `PRIORITY` int(11) NOT NULL COMMENT '우선순위',
  `STATE` varchar(16) NOT NULL COMMENT '상태',
  `JOB_NAME` varchar(200) DEFAULT NULL COMMENT 'Job 이름',
  `JOB_GROUP` varchar(200) DEFAULT NULL COMMENT 'Job 그룹',
  `IS_NONCONCURRENT` varchar(1) DEFAULT NULL COMMENT '동시 실행 불가 여부',
  `REQUESTS_RECOVERY` varchar(1) DEFAULT NULL COMMENT '복구 요청 여부',
  PRIMARY KEY (`SCHED_NAME`,`ENTRY_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Quartz 실행된 트리거 정보';


-- maestro.QRTZ_JOB_DETAILS definition

CREATE OR REPLACE TABLE `QRTZ_JOB_DETAILS` (
  `SCHED_NAME` varchar(120) NOT NULL COMMENT '스케줄러 이름',
  `JOB_NAME` varchar(200) NOT NULL COMMENT 'Job 이름',
  `JOB_GROUP` varchar(200) NOT NULL COMMENT 'Job 그룹',
  `DESCRIPTION` varchar(250) DEFAULT NULL COMMENT '설명',
  `JOB_CLASS_NAME` varchar(250) NOT NULL COMMENT 'Job 클래스 이름',
  `IS_DURABLE` varchar(1) NOT NULL COMMENT '지속 가능 여부',
  `IS_NONCONCURRENT` varchar(1) NOT NULL COMMENT '동시 실행 불가 여부',
  `IS_UPDATE_DATA` varchar(1) NOT NULL COMMENT '데이터 업데이트 여부',
  `REQUESTS_RECOVERY` varchar(1) NOT NULL COMMENT '복구 요청 여부',
  `JOB_DATA` blob DEFAULT NULL COMMENT 'Job 데이터',
  PRIMARY KEY (`SCHED_NAME`,`JOB_NAME`,`JOB_GROUP`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Quartz Job 정보';


-- maestro.QRTZ_LOCKS definition

CREATE OR REPLACE TABLE `QRTZ_LOCKS` (
  `SCHED_NAME` varchar(120) NOT NULL COMMENT '스케줄러 이름',
  `LOCK_NAME` varchar(40) NOT NULL COMMENT '락 이름',
  PRIMARY KEY (`SCHED_NAME`,`LOCK_NAME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Quartz 락 정보';


-- maestro.QRTZ_PAUSED_TRIGGER_GRPS definition

CREATE OR REPLACE TABLE `QRTZ_PAUSED_TRIGGER_GRPS` (
  `SCHED_NAME` varchar(120) NOT NULL COMMENT '스케줄러 이름',
  `TRIGGER_GROUP` varchar(200) NOT NULL COMMENT '트리거 그룹',
  PRIMARY KEY (`SCHED_NAME`,`TRIGGER_GROUP`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Quartz 일시정지된 트리거 그룹 정보';


-- maestro.QRTZ_SCHEDULER_EVENT definition

CREATE OR REPLACE TABLE `QRTZ_SCHEDULER_EVENT` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(500) DEFAULT NULL,
  `description` varchar(2000) DEFAULT NULL,
  `path` text DEFAULT NULL,
  `body` text DEFAULT NULL,
  `header` text DEFAULT NULL,
  `solution_id` varchar(36) DEFAULT NULL,
  `solution` varchar(127) DEFAULT NULL,
  `service` varchar(127) DEFAULT NULL,
  `resource_type` varchar(127) DEFAULT NULL,
  `method` varchar(127) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `service_type_id` varchar(36) DEFAULT NULL,
  KEY `UMTAEHYEOK_EVENT_create_time_index` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.QRTZ_SCHEDULER_STATE definition

CREATE OR REPLACE TABLE `QRTZ_SCHEDULER_STATE` (
  `SCHED_NAME` varchar(120) NOT NULL COMMENT '스케줄러 이름',
  `INSTANCE_NAME` varchar(200) NOT NULL COMMENT '인스턴스 이름',
  `LAST_CHECKIN_TIME` bigint(13) NOT NULL COMMENT '마지막 체크인 시간',
  `CHECKIN_INTERVAL` bigint(13) NOT NULL COMMENT '체크인 간격',
  PRIMARY KEY (`SCHED_NAME`,`INSTANCE_NAME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Quartz 스케줄러 상태 정보';


-- maestro.SVC_REQUEST_API definition

CREATE OR REPLACE TABLE `SVC_REQUEST_API` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `method` varchar(10) NOT NULL,
  `endpoint` varchar(255) NOT NULL,
  `header` text DEFAULT NULL,
  `body` text DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `step` int(11) DEFAULT 1,
  `service_request_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ADMIN_FOLDER definition

CREATE OR REPLACE TABLE `MSTR_ADMIN_FOLDER` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `description` text DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `depth` int(11) NOT NULL,
  `status` int(11) DEFAULT 0,
  `parent_id` varchar(36) DEFAULT NULL,
  `org_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_FOLDER_1` (`parent_id`),
  KEY `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_FOLDER_2` (`org_id`),
  CONSTRAINT `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_FOLDER_1` FOREIGN KEY (`parent_id`) REFERENCES `MSTR_ADMIN_FOLDER` (`id`),
  CONSTRAINT `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_FOLDER_2` FOREIGN KEY (`org_id`) REFERENCES `MSTR_ADMIN_FOLDER` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ADMIN_GROUP definition

CREATE OR REPLACE TABLE `MSTR_ADMIN_GROUP` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `description` text DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `org_id` varchar(36) NOT NULL,
  `group_email` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_GROUP_1` (`org_id`),
  CONSTRAINT `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_GROUP_1` FOREIGN KEY (`org_id`) REFERENCES `MSTR_ADMIN_FOLDER` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ADMIN_IN_FOLDER definition

CREATE OR REPLACE TABLE `MSTR_ADMIN_IN_FOLDER` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `user_id` varchar(36) NOT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `name` varchar(127) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `folder_id` varchar(36) NOT NULL,
  `status` int(11) DEFAULT 0,
  `is_guest` int(11) DEFAULT 0,
  `is_org` int(11) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_IN_FOLDER_1` (`folder_id`),
  CONSTRAINT `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_IN_FOLDER_1` FOREIGN KEY (`folder_id`) REFERENCES `MSTR_ADMIN_FOLDER` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ADMIN_IN_GROUP definition

CREATE OR REPLACE TABLE `MSTR_ADMIN_IN_GROUP` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `group_id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_ADMIN_GROUP_TO_MSTR_ADMIN_IN_GROUP_1` (`group_id`),
  CONSTRAINT `FK_MSTR_ADMIN_GROUP_TO_MSTR_ADMIN_IN_GROUP_1` FOREIGN KEY (`group_id`) REFERENCES `MSTR_ADMIN_GROUP` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_BOARD_RECOMMENDATION definition

CREATE OR REPLACE TABLE `MSTR_BOARD_RECOMMENDATION` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `board_id` varchar(36) NOT NULL,
  `user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `MSTR_BOARD_RECOMMENDATION_MSTR_BOARD_id_fk` (`board_id`),
  CONSTRAINT `MSTR_BOARD_RECOMMENDATION_MSTR_BOARD_id_fk` FOREIGN KEY (`board_id`) REFERENCES `MSTR_BOARD` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ENDPOINT_IN_AUTHORITY definition

CREATE OR REPLACE TABLE `MSTR_ENDPOINT_IN_AUTHORITY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `authority_id` varchar(36) NOT NULL,
  `endpoint_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `MSTR_ENDPOINT_IN_AUTHORITY_MSTR_AUTHORITY_id_fk` (`authority_id`),
  KEY `MSTR_ENDPOINT_IN_AUTHORITY_MSTR_ENDPOINT_id_fk` (`endpoint_id`),
  CONSTRAINT `MSTR_ENDPOINT_IN_AUTHORITY_MSTR_AUTHORITY_id_fk` FOREIGN KEY (`authority_id`) REFERENCES `MSTR_AUTHORITY` (`id`),
  CONSTRAINT `MSTR_ENDPOINT_IN_AUTHORITY_MSTR_ENDPOINT_id_fk` FOREIGN KEY (`endpoint_id`) REFERENCES `MSTR_ENDPOINT` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ENDPOINT_IN_LOG_TAG definition

CREATE OR REPLACE TABLE `MSTR_ENDPOINT_IN_LOG_TAG` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `endpoint_id` varchar(36) NOT NULL DEFAULT uuid(),
  `log_tag_id` varchar(36) NOT NULL DEFAULT uuid(),
  PRIMARY KEY (`id`),
  KEY `MSTR_ENDPOINT_IN_LOG_TAG_MSTR_ENDPOINT_id_fk` (`endpoint_id`),
  KEY `MSTR_ENDPOINT_IN_LOG_TAG_MSTR_LOG_TAG_id_fk` (`log_tag_id`),
  CONSTRAINT `MSTR_ENDPOINT_IN_LOG_TAG_MSTR_ENDPOINT_id_fk` FOREIGN KEY (`endpoint_id`) REFERENCES `MSTR_ENDPOINT` (`id`),
  CONSTRAINT `MSTR_ENDPOINT_IN_LOG_TAG_MSTR_LOG_TAG_id_fk` FOREIGN KEY (`log_tag_id`) REFERENCES `MSTR_LOG_TAG` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ENDPOINT_SERVICE_IN_SOLUTION definition

CREATE OR REPLACE TABLE `MSTR_ENDPOINT_SERVICE_IN_SOLUTION` (
  `service` varchar(127) NOT NULL,
  `solution_id` varchar(36) NOT NULL,
  PRIMARY KEY (`service`,`solution_id`),
  KEY `MSTR_ENDPOINT_SERVICE_IN_SOLUTION_MSTR_SOLUTION_null_fk` (`solution_id`),
  CONSTRAINT `FK_MSTR_ENDPOINT_SERVICE_TO_MSTR_ENDPOINT_SERVICE_IN_SOLUTION_1` FOREIGN KEY (`service`) REFERENCES `MSTR_ENDPOINT_SERVICE` (`name`),
  CONSTRAINT `MSTR_ENDPOINT_SERVICE_IN_SOLUTION_MSTR_SOLUTION_null_fk` FOREIGN KEY (`solution_id`) REFERENCES `MSTR_SOLUTION` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

-- maestro.MSTR_INFRA_FOLDER definition

CREATE OR REPLACE TABLE `MSTR_INFRA_FOLDER` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `description` text DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `depth` int(11) NOT NULL,
  `parent_id` varchar(36) DEFAULT NULL,
  `root_infra_id` varchar(36) DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `MSTR_INFRA_FOLDER_pk` (`parent_id`,`name`),
  KEY `MSTR_INFRA_FOLDER_MSTR_INFRA_FOLDER_id_fk` (`root_infra_id`),
  KEY `MSTR_INFRA_FOLDER_create_time_index` (`create_time`),
  CONSTRAINT `MSTR_INFRA_FOLDER_MSTR_INFRA_FOLDER_id_fk` FOREIGN KEY (`root_infra_id`) REFERENCES `MSTR_INFRA_FOLDER` (`id`),
  CONSTRAINT `MSTR_INFRA_FOLDER_parent_id_fk` FOREIGN KEY (`parent_id`) REFERENCES `MSTR_INFRA_FOLDER` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_MENU definition

CREATE OR REPLACE TABLE `MSTR_MENU` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(500) DEFAULT NULL,
  `description` varchar(2000) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `position` int(11) NOT NULL DEFAULT 0,
  `depth` int(11) NOT NULL DEFAULT 0,
  `path` varchar(500) DEFAULT NULL,
  `selector` varchar(500) DEFAULT NULL,
  `global_menu_id` varchar(500) DEFAULT NULL,
  `en_name` varchar(255) DEFAULT NULL,
  `icon_path` varchar(2000) DEFAULT NULL,
  `parent_id` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_MENU_TO_MSTR_MENU_1` (`parent_id`),
  CONSTRAINT `FK_MSTR_MENU_TO_MSTR_MENU_1` FOREIGN KEY (`parent_id`) REFERENCES `MSTR_MENU` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_MENU_AUTHORITY definition

CREATE OR REPLACE TABLE `MSTR_MENU_AUTHORITY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `authority_id` varchar(36) NOT NULL DEFAULT uuid(),
  `menu_id` varchar(36) NOT NULL DEFAULT uuid(),
  `feature_types` varchar(2000) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_AUTHORITY_TO_MSTR_MENU_AUTHORITY_1` (`authority_id`),
  KEY `FK_MSTR_MENU_TO_MSTR_MENU_AUTHORITY_1` (`menu_id`),
  CONSTRAINT `FK_MSTR_AUTHORITY_TO_MSTR_MENU_AUTHORITY_1` FOREIGN KEY (`authority_id`) REFERENCES `MSTR_AUTHORITY` (`id`),
  CONSTRAINT `FK_MSTR_MENU_TO_MSTR_MENU_AUTHORITY_1` FOREIGN KEY (`menu_id`) REFERENCES `MSTR_MENU` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_AND_GROUP definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_AND_GROUP` (
  `notification_id` varchar(255) NOT NULL,
  `receive_group_id` varchar(255) NOT NULL,
  PRIMARY KEY (`notification_id`,`receive_group_id`),
  KEY `receive_group_id` (`receive_group_id`),
  CONSTRAINT `MSTR_NOTIFICATION_AND_GROUP_ibfk_1` FOREIGN KEY (`notification_id`) REFERENCES `MSTR_NOTIFICATION` (`id`),
  CONSTRAINT `MSTR_NOTIFICATION_AND_GROUP_ibfk_2` FOREIGN KEY (`receive_group_id`) REFERENCES `MSTR_NOTIFICATION_RECEIVE_GROUP` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_COMMON_CODE definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_COMMON_CODE` (
  `code` varchar(255) NOT NULL,
  `code_type_id` varchar(255) DEFAULT NULL,
  `parent_code` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT NULL,
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(255) DEFAULT 'Y',
  PRIMARY KEY (`code`),
  KEY `code_type_id` (`code_type_id`),
  KEY `parent_code` (`parent_code`),
  CONSTRAINT `MSTR_NOTIFICATION_COMMON_CODE_ibfk_1` FOREIGN KEY (`code_type_id`) REFERENCES `MSTR_NOTIFICATION_COMMON_CODE_TYPE` (`code_type_id`),
  CONSTRAINT `MSTR_NOTIFICATION_COMMON_CODE_ibfk_2` FOREIGN KEY (`parent_code`) REFERENCES `MSTR_NOTIFICATION_COMMON_CODE` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_EVENT definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_EVENT` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `event_code_id` varchar(255) DEFAULT NULL,
  `solution_id` varchar(255) DEFAULT NULL,
  `main_classification_code` varchar(255) DEFAULT NULL,
  `main_classification_name` varchar(255) DEFAULT NULL,
  `sub_classification_code` varchar(255) DEFAULT NULL,
  `sub_classification_name` varchar(255) DEFAULT NULL,
  `sub_message` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT NULL,
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(255) DEFAULT 'Y',
  PRIMARY KEY (`id`),
  KEY `event_code_id` (`event_code_id`),
  KEY `solution_id` (`solution_id`),
  CONSTRAINT `MSTR_NOTIFICATION_EVENT_ibfk_1` FOREIGN KEY (`event_code_id`) REFERENCES `MSTR_NOTIFICATION_EVENT_CODE` (`id`),
  CONSTRAINT `MSTR_NOTIFICATION_EVENT_ibfk_2` FOREIGN KEY (`solution_id`) REFERENCES `MSTR_SOLUTION` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_IN_GROUP definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_IN_GROUP` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `group_id` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `user_id` varchar(255) DEFAULT uuid(),
  `phone` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `external_yn` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT 'USER',
  `create_date` timestamp NULL DEFAULT current_timestamp(),
  `update_date` timestamp NULL DEFAULT NULL,
  `create_user` varchar(255) DEFAULT NULL,
  `update_user` varchar(255) DEFAULT NULL,
  `use_yn` varchar(255) DEFAULT 'Y',
  PRIMARY KEY (`id`),
  KEY `group_id` (`group_id`),
  CONSTRAINT `MSTR_NOTIFICATION_IN_GROUP_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `MSTR_NOTIFICATION_RECEIVE_GROUP` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_PLATFORM definition

CREATE OR REPLACE TABLE `MSTR_PLATFORM` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `solution_id` varchar(36) DEFAULT NULL,
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `MSTR_PLATFORM_MSTR_SOLUTION_id_fk` (`solution_id`),
  CONSTRAINT `MSTR_PLATFORM_MSTR_SOLUTION_id_fk` FOREIGN KEY (`solution_id`) REFERENCES `MSTR_SOLUTION` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_PROVIDER definition

CREATE OR REPLACE TABLE `MSTR_PROVIDER` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `description` text DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `parent_id` varchar(36) DEFAULT NULL,
  `root_infra_id` varchar(36) DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `type` int(11) DEFAULT 1,
  `url` varchar(127) DEFAULT NULL,
  `place` varchar(255) DEFAULT NULL,
  `platform_type` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `MSTR_PROVIDER_MSTR_PROVIDER_TYPE_null_fk` (`type`),
  KEY `MSTR_PROVIDER_create_time_index` (`create_time`),
  CONSTRAINT `MSTR_PROVIDER_MSTR_PROVIDER_TYPE_null_fk` FOREIGN KEY (`type`) REFERENCES `MSTR_PROVIDER_TYPE` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_REQUEST_OF_SERVICE_TYPE definition

CREATE OR REPLACE TABLE `MSTR_REQUEST_OF_SERVICE_TYPE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) NOT NULL,
  `description` text DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT current_timestamp(),
  `status` int(11) DEFAULT 0,
  `operation_code` varchar(20) DEFAULT NULL,
  `category_id` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_SERVICE_CATEGORY_TO_MSTR_REQUEST_OF_SERVICE_TYPE` (`category_id`),
  CONSTRAINT `FK_SERVICE_CATEGORY_TO_MSTR_REQUEST_OF_SERVICE_TYPE_1` FOREIGN KEY (`category_id`) REFERENCES `MSTR_REQUEST_OF_SERVICE_CATEGORY` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ROLE_CATEGORY definition

CREATE OR REPLACE TABLE `MSTR_ROLE_CATEGORY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `description` varchar(255) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `type_id` varchar(36) NOT NULL,
  `selector` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_ROLE_TYPE_TO_MSTR_ROLE_CATEGORY_1` (`type_id`),
  CONSTRAINT `FK_MSTR_ROLE_TYPE_TO_MSTR_ROLE_CATEGORY_1` FOREIGN KEY (`type_id`) REFERENCES `MSTR_ROLE_TYPE` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ROLE_DEPLOY definition

CREATE OR REPLACE TABLE `MSTR_ROLE_DEPLOY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 1,
  `org_id` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_FOLDER_TO_MSTR_ROLE_DEPLOY_1` (`org_id`),
  CONSTRAINT `FK_MSTR_FOLDER_TO_MSTR_ROLE_DEPLOY_1` FOREIGN KEY (`org_id`) REFERENCES `MSTR_FOLDER` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ROLE_DEPLOY_OPTION definition

CREATE OR REPLACE TABLE `MSTR_ROLE_DEPLOY_OPTION` (
  `deploy_id` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `type` varchar(255) DEFAULT 'options',
  `value` varchar(4000) NOT NULL,
  `create_user_id` varchar(255) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`deploy_id`,`name`),
  KEY `MSTR_ROLE_DEPLOY_DEFAULT_pk` (`deploy_id`),
  CONSTRAINT `MSTR_ROLE_DEPLOY_DEFAULT_MSTR_ROLE_DEPLOY_id_fk` FOREIGN KEY (`deploy_id`) REFERENCES `MSTR_ROLE_DEPLOY` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='service, default deploy 등의 옵션이 기록되는 테이블';


-- maestro.MSTR_SOLUTION_SERVER definition

CREATE OR REPLACE TABLE `MSTR_SOLUTION_SERVER` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `status` int(11) DEFAULT 1,
  `description` varchar(255) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT current_timestamp(),
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `solution_id` varchar(36) NOT NULL,
  `is_admin` int(11) DEFAULT 1,
  `base_path` varchar(127) DEFAULT NULL,
  `api_docs_path` varchar(127) DEFAULT NULL,
  `nickname` varchar(127) DEFAULT NULL COMMENT '별칭',
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_SOLUTION_TO_MSTR_SOLUTION_SERVER_1` (`solution_id`),
  CONSTRAINT `FK_MSTR_SOLUTION_TO_MSTR_SOLUTION_SERVER_1` FOREIGN KEY (`solution_id`) REFERENCES `MSTR_SOLUTION` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_USER_IN_FOLDER definition

CREATE OR REPLACE TABLE `MSTR_USER_IN_FOLDER` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `user_id` varchar(36) NOT NULL,
  `folder_id` varchar(36) NOT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `name` varchar(127) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `status` tinyint(4) DEFAULT 0,
  `is_guest` tinyint(1) DEFAULT NULL,
  `is_org` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `MSTR_USER_IN_FOLDER_MSTR_FOLDER_null_fk` (`folder_id`),
  KEY `MSTR_USER_IN_FOLDER_create_time_index` (`create_time`),
  CONSTRAINT `MSTR_USER_IN_FOLDER_MSTR_FOLDER_null_fk` FOREIGN KEY (`folder_id`) REFERENCES `MSTR_FOLDER` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_USER_IN_GROUP definition

CREATE OR REPLACE TABLE `MSTR_USER_IN_GROUP` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `user_id` varchar(36) NOT NULL,
  `user_group_id` varchar(36) NOT NULL DEFAULT uuid(),
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_USER_GROUP_TO_MSTR_USER_IN_GROUP_1` (`user_group_id`),
  CONSTRAINT `FK_MSTR_USER_GROUP_TO_MSTR_USER_IN_GROUP_1` FOREIGN KEY (`user_group_id`) REFERENCES `MSTR_USER_GROUP` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_WORKSPACE_CONNECTION definition

CREATE OR REPLACE TABLE `MSTR_WORKSPACE_CONNECTION` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `workspace_id` varchar(36) NOT NULL,
  `provider_id` varchar(36) NOT NULL,
  `tenant_name` varchar(127) NOT NULL DEFAULT 'Default',
  `tenant_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `MSTR_WORKSPACE_CONNECTION_MSTR_PROVIDER_null_fk` (`provider_id`),
  KEY `MSTR_WORKSPACE_CONNECTION_MSTR_WORKSPACE_null_fk` (`workspace_id`),
  CONSTRAINT `MSTR_WORKSPACE_CONNECTION_MSTR_PROVIDER_null_fk` FOREIGN KEY (`provider_id`) REFERENCES `MSTR_PROVIDER` (`id`),
  CONSTRAINT `MSTR_WORKSPACE_CONNECTION_MSTR_WORKSPACE_null_fk` FOREIGN KEY (`workspace_id`) REFERENCES `MSTR_WORKSPACE` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.QRTZ_TRIGGERS definition

CREATE OR REPLACE TABLE `QRTZ_TRIGGERS` (
  `SCHED_NAME` varchar(120) NOT NULL COMMENT '스케줄러 이름',
  `TRIGGER_NAME` varchar(200) NOT NULL COMMENT '트리거 이름',
  `TRIGGER_GROUP` varchar(200) NOT NULL COMMENT '트리거 그룹',
  `JOB_NAME` varchar(200) NOT NULL COMMENT 'Job 이름',
  `JOB_GROUP` varchar(200) NOT NULL COMMENT 'Job 그룹',
  `DESCRIPTION` varchar(250) DEFAULT NULL COMMENT '설명',
  `NEXT_FIRE_TIME` bigint(13) DEFAULT NULL COMMENT '다음 실행 시간',
  `PREV_FIRE_TIME` bigint(13) DEFAULT NULL COMMENT '이전 실행 시간',
  `PRIORITY` int(11) DEFAULT NULL COMMENT '우선순위',
  `TRIGGER_STATE` varchar(16) NOT NULL COMMENT '트리거 상태',
  `TRIGGER_TYPE` varchar(8) NOT NULL COMMENT '트리거 타입',
  `START_TIME` bigint(13) NOT NULL COMMENT '시작 시간',
  `END_TIME` bigint(13) DEFAULT NULL COMMENT '종료 시간',
  `CALENDAR_NAME` varchar(200) DEFAULT NULL COMMENT '캘린더 이름',
  `MISFIRE_INSTR` smallint(6) DEFAULT NULL COMMENT '미스파이어 지시자',
  `JOB_DATA` blob DEFAULT NULL COMMENT 'Job 데이터',
  PRIMARY KEY (`SCHED_NAME`,`TRIGGER_NAME`,`TRIGGER_GROUP`),
  KEY `SCHED_NAME` (`SCHED_NAME`,`JOB_NAME`,`JOB_GROUP`),
  CONSTRAINT `QRTZ_TRIGGERS_ibfk_1` FOREIGN KEY (`SCHED_NAME`, `JOB_NAME`, `JOB_GROUP`) REFERENCES `QRTZ_JOB_DETAILS` (`SCHED_NAME`, `JOB_NAME`, `JOB_GROUP`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Quartz 트리거 정보';


-- maestro.MSTR_FOLDER_IN_ROLE_DEPLOY definition

CREATE OR REPLACE TABLE `MSTR_FOLDER_IN_ROLE_DEPLOY` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `org_id` varchar(36) NOT NULL,
  `deploy_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_FOLDER_TO_MSTR_FOLDER_IN_ROLE_DEPLOY_1` (`org_id`),
  KEY `FK_MSTR_ROLE_DEPLOY_TO_MSTR_FOLDER_IN_ROLE_DEPLOY_1` (`deploy_id`),
  CONSTRAINT `FK_MSTR_FOLDER_TO_MSTR_FOLDER_IN_ROLE_DEPLOY_1` FOREIGN KEY (`org_id`) REFERENCES `MSTR_FOLDER` (`id`),
  CONSTRAINT `FK_MSTR_ROLE_DEPLOY_TO_MSTR_FOLDER_IN_ROLE_DEPLOY_1` FOREIGN KEY (`deploy_id`) REFERENCES `MSTR_ROLE_DEPLOY` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_GLOBAL_MENU definition

CREATE OR REPLACE TABLE `MSTR_GLOBAL_MENU` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `description` varchar(2000) DEFAULT NULL,
  `solution_id` varchar(36) NOT NULL,
  `platform_id` varchar(36) DEFAULT NULL,
  `name` varchar(500) DEFAULT NULL,
  `type` varchar(127) DEFAULT NULL,
  `icon` varchar(500) DEFAULT NULL,
  `last_layout_changed_time` timestamp NULL DEFAULT NULL,
  `last_layout_chagned_user_id` varchar(500) DEFAULT NULL,
  `path` varchar(500) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `MSTR_GLOBAL_MENU_MSTR_PLATFORM_null_fk` (`platform_id`),
  KEY `MSTR_GLOBAL_MENU_MSTR_SOLUTION_null_fk` (`solution_id`),
  CONSTRAINT `MSTR_GLOBAL_MENU_MSTR_PLATFORM_null_fk` FOREIGN KEY (`platform_id`) REFERENCES `MSTR_PLATFORM` (`id`),
  CONSTRAINT `MSTR_GLOBAL_MENU_MSTR_SOLUTION_null_fk` FOREIGN KEY (`solution_id`) REFERENCES `MSTR_SOLUTION` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_NOTIFICATION_AND_EVENT definition

CREATE OR REPLACE TABLE `MSTR_NOTIFICATION_AND_EVENT` (
  `event_id` varchar(255) NOT NULL,
  `notification_id` varchar(255) NOT NULL,
  PRIMARY KEY (`event_id`,`notification_id`),
  KEY `notification_id` (`notification_id`),
  CONSTRAINT `MSTR_NOTIFICATION_AND_EVENT_ibfk_1` FOREIGN KEY (`event_id`) REFERENCES `MSTR_NOTIFICATION_EVENT` (`id`),
  CONSTRAINT `MSTR_NOTIFICATION_AND_EVENT_ibfk_2` FOREIGN KEY (`notification_id`) REFERENCES `MSTR_NOTIFICATION` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_REQUEST_OF_SERVICE_OBJECT definition

CREATE OR REPLACE TABLE `MSTR_REQUEST_OF_SERVICE_OBJECT` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `create_user_id` varchar(36) NOT NULL,
  `create_time` timestamp NULL DEFAULT current_timestamp(),
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp(),
  `status` int(11) DEFAULT 0,
  `service_object_id` varchar(36) DEFAULT NULL,
  `request_user_id` varchar(36) DEFAULT NULL,
  `manager_id` varchar(36) DEFAULT NULL,
  `provider_id` varchar(36) DEFAULT NULL,
  `tenant_id` varchar(36) DEFAULT NULL,
  `request_time` timestamp NULL DEFAULT NULL,
  `desired_end_time` timestamp NULL DEFAULT NULL,
  `content` varchar(1000) DEFAULT NULL,
  `type` int(11) DEFAULT 0,
  `file_path` varchar(255) DEFAULT NULL,
  `variables` text DEFAULT NULL,
  `approve_time` timestamp NULL DEFAULT NULL,
  `progress_time` timestamp NULL DEFAULT NULL,
  `end_time` timestamp NULL DEFAULT NULL,
  `detail` text DEFAULT NULL,
  `provision_file_path` varchar(255) DEFAULT NULL,
  `provision_log` text DEFAULT NULL,
  `yaml` text DEFAULT NULL,
  `folder_id` varchar(36) DEFAULT NULL,
  `org_id` varchar(36) DEFAULT NULL,
  `resource_info` text DEFAULT NULL,
  `request_type_id` varchar(36) DEFAULT NULL,
  `admin_setting` tinyint(1) DEFAULT 0,
  `config_map` text DEFAULT NULL COMMENT '변수로 치환할 값에 대해 map 형태로 구성된 값입니다',
  `reason` varchar(255) DEFAULT NULL,
  `workspace_id` varchar(36) DEFAULT NULL,
  `scheduled_time` timestamp NULL DEFAULT NULL,
  `return_time` timestamp NULL DEFAULT NULL,
  KEY `FK_SERVICE_TYPE_TO_MSTR_REQUEST_OF_SERVICE_OBJECT` (`request_type_id`),
  CONSTRAINT `FK_SERVICE_TYPE_TO_MSTR_REQUEST_OF_SERVICE_OBJECT` FOREIGN KEY (`request_type_id`) REFERENCES `MSTR_REQUEST_OF_SERVICE_TYPE` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ROLE definition

CREATE OR REPLACE TABLE `MSTR_ROLE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `name` varchar(127) DEFAULT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `update_user_id` varchar(36) DEFAULT NULL,
  `update_time` timestamp NULL DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `selector` varchar(255) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `category_id` varchar(36) NOT NULL,
  `open_org` int(11) DEFAULT 0,
  `open_folder` int(11) DEFAULT 0,
  `open_workspace` int(11) DEFAULT 0,
  `role_type_id` varchar(36) DEFAULT NULL,
  `is_default` int(11) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_ROLE_CATEGORY_TO_MSTR_ROLE_1` (`category_id`),
  KEY `MSTR_ROLE_MSTR_ROLE_TYPE_id_fk` (`role_type_id`),
  CONSTRAINT `FK_MSTR_ROLE_CATEGORY_TO_MSTR_ROLE_1` FOREIGN KEY (`category_id`) REFERENCES `MSTR_ROLE_CATEGORY` (`id`),
  CONSTRAINT `MSTR_ROLE_MSTR_ROLE_TYPE_id_fk` FOREIGN KEY (`role_type_id`) REFERENCES `MSTR_ROLE_TYPE` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ROLE_DEPLOYED definition

CREATE OR REPLACE TABLE `MSTR_ROLE_DEPLOYED` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `deploy_id` varchar(36) NOT NULL,
  `role_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `MSTR_ROLE_DEPLOYED_pk` (`deploy_id`,`role_id`),
  KEY `FK_MSTR_ROLE_TO_MSTR_DEPLOYED_ROLE_1` (`role_id`),
  CONSTRAINT `FK_MSTR_ROLE_DEPLOY_TO_MSTR_DEPLOYED_ROLE_1` FOREIGN KEY (`deploy_id`) REFERENCES `MSTR_ROLE_DEPLOY` (`id`),
  CONSTRAINT `FK_MSTR_ROLE_TO_MSTR_DEPLOYED_ROLE_1` FOREIGN KEY (`role_id`) REFERENCES `MSTR_ROLE` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_USER_FOLDER_ROLE definition

CREATE OR REPLACE TABLE `MSTR_USER_FOLDER_ROLE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `folder_id` varchar(36) NOT NULL,
  `user_in_folder_id` varchar(36) NOT NULL,
  `deployed_role_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `MSTR_USER_FOLDER_ROLE_pk` (`folder_id`,`user_in_folder_id`,`deployed_role_id`),
  KEY `FK_MSTR_DEPLOYED_ROLE_TO_MSTR_USER_FOLDER_ROLE_1` (`deployed_role_id`),
  KEY `FK_MSTR_USER_IN_FOLDER_TO_MSTR_USER_FOLDER_ROLE_1` (`user_in_folder_id`),
  CONSTRAINT `FK_MSTR_DEPLOYED_ROLE_TO_MSTR_USER_FOLDER_ROLE_1` FOREIGN KEY (`deployed_role_id`) REFERENCES `MSTR_ROLE_DEPLOYED` (`id`),
  CONSTRAINT `FK_MSTR_FOLDER_TO_MSTR_USER_FOLDER_ROLE_1` FOREIGN KEY (`folder_id`) REFERENCES `MSTR_FOLDER` (`id`),
  CONSTRAINT `FK_MSTR_USER_IN_FOLDER_TO_MSTR_USER_FOLDER_ROLE_1` FOREIGN KEY (`user_in_folder_id`) REFERENCES `MSTR_USER_IN_FOLDER` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_USER_GROUP_FOLDER_ROLE definition

CREATE OR REPLACE TABLE `MSTR_USER_GROUP_FOLDER_ROLE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `user_group_id` varchar(36) NOT NULL,
  `deployed_role_id` varchar(36) NOT NULL,
  `folder_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `MSTR_USER_GROUP_FOLDER_ROLE_pk` (`folder_id`,`user_group_id`,`deployed_role_id`),
  KEY `FK_MSTR_DEPLOYED_ROLE_TO_MSTR_USER_GROUP_FOLDER_ROLE_1` (`deployed_role_id`),
  KEY `FK_MSTR_USER_GROUP_TO_MSTR_USER_GROUP_FOLDER_ROLE_1` (`user_group_id`),
  CONSTRAINT `FK_MSTR_DEPLOYED_ROLE_TO_MSTR_USER_GROUP_FOLDER_ROLE_1` FOREIGN KEY (`deployed_role_id`) REFERENCES `MSTR_ROLE_DEPLOYED` (`id`),
  CONSTRAINT `FK_MSTR_FOLDER_TO_MSTR_USER_GROUP_FOLDER_ROLE_1` FOREIGN KEY (`folder_id`) REFERENCES `MSTR_FOLDER` (`id`),
  CONSTRAINT `FK_MSTR_USER_GROUP_TO_MSTR_USER_GROUP_FOLDER_ROLE_1` FOREIGN KEY (`user_group_id`) REFERENCES `MSTR_USER_GROUP` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_USER_GROUP_WORKSPACE_ROLE definition

CREATE OR REPLACE TABLE `MSTR_USER_GROUP_WORKSPACE_ROLE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `user_group_id` varchar(36) NOT NULL,
  `deployed_role_id` varchar(36) NOT NULL,
  `workspace_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `MSTR_USER_GROUP_WORKSPACE_ROLE_pk` (`workspace_id`,`user_group_id`,`deployed_role_id`),
  KEY `FK_MSTR_DEPLOYED_ROLE_TO_CopyOfMSTR_USER_GROUP_FOLDER_ROLE_1` (`deployed_role_id`),
  KEY `FK_MSTR_USER_GROUP_TO_CopyOfMSTR_USER_GROUP_FOLDER_ROLE_1` (`user_group_id`),
  CONSTRAINT `FK_MSTR_DEPLOYED_ROLE_TO_CopyOfMSTR_USER_GROUP_FOLDER_ROLE_1` FOREIGN KEY (`deployed_role_id`) REFERENCES `MSTR_ROLE_DEPLOYED` (`id`),
  CONSTRAINT `FK_MSTR_USER_GROUP_TO_CopyOfMSTR_USER_GROUP_FOLDER_ROLE_1` FOREIGN KEY (`user_group_id`) REFERENCES `MSTR_USER_GROUP` (`id`),
  CONSTRAINT `FK_MSTR_WORKSPACE_TO_CopyOfMSTR_USER_GROUP_FOLDER_ROLE_1` FOREIGN KEY (`workspace_id`) REFERENCES `MSTR_WORKSPACE` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_USER_WORKSPACE_ROLE definition

CREATE OR REPLACE TABLE `MSTR_USER_WORKSPACE_ROLE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `workspace_id` varchar(36) NOT NULL,
  `user_in_folder_id` varchar(36) NOT NULL,
  `deployed_role_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `MSTR_USER_WORKSPACE_ROLE_pk` (`deployed_role_id`,`user_in_folder_id`,`workspace_id`),
  KEY `FK_MSTR_USER_IN_FOLDER_TO_MSTR_USER_WORKSPACE_ROLE_1` (`user_in_folder_id`),
  KEY `FK_MSTR_WORKSPACE_TO_MSTR_USER_WORKSPACE_ROLE_1` (`workspace_id`),
  CONSTRAINT `FK_MSTR_DEPLOYED_ROLE_TO_MSTR_USER_WORKSPACE_ROLE_1` FOREIGN KEY (`deployed_role_id`) REFERENCES `MSTR_ROLE_DEPLOYED` (`id`),
  CONSTRAINT `FK_MSTR_USER_IN_FOLDER_TO_MSTR_USER_WORKSPACE_ROLE_1` FOREIGN KEY (`user_in_folder_id`) REFERENCES `MSTR_USER_IN_FOLDER` (`id`),
  CONSTRAINT `FK_MSTR_WORKSPACE_TO_MSTR_USER_WORKSPACE_ROLE_1` FOREIGN KEY (`workspace_id`) REFERENCES `MSTR_WORKSPACE` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.QRTZ_BLOB_TRIGGERS definition

CREATE OR REPLACE TABLE `QRTZ_BLOB_TRIGGERS` (
  `SCHED_NAME` varchar(120) NOT NULL COMMENT '스케줄러 이름',
  `TRIGGER_NAME` varchar(200) NOT NULL COMMENT '트리거 이름',
  `TRIGGER_GROUP` varchar(200) NOT NULL COMMENT '트리거 그룹',
  `BLOB_DATA` blob DEFAULT NULL COMMENT 'BLOB 데이터',
  PRIMARY KEY (`SCHED_NAME`,`TRIGGER_NAME`,`TRIGGER_GROUP`),
  CONSTRAINT `QRTZ_BLOB_TRIGGERS_ibfk_1` FOREIGN KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`) REFERENCES `QRTZ_TRIGGERS` (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Quartz BLOB 트리거 정보';


-- maestro.QRTZ_CRON_TRIGGERS definition

CREATE OR REPLACE TABLE `QRTZ_CRON_TRIGGERS` (
  `SCHED_NAME` varchar(120) NOT NULL COMMENT '스케줄러 이름',
  `TRIGGER_NAME` varchar(200) NOT NULL COMMENT '트리거 이름',
  `TRIGGER_GROUP` varchar(200) NOT NULL COMMENT '트리거 그룹',
  `CRON_EXPRESSION` varchar(120) NOT NULL COMMENT 'Cron 표현식',
  `TIME_ZONE_ID` varchar(80) DEFAULT NULL COMMENT '시간대 식별자',
  PRIMARY KEY (`SCHED_NAME`,`TRIGGER_NAME`,`TRIGGER_GROUP`),
  CONSTRAINT `QRTZ_CRON_TRIGGERS_ibfk_1` FOREIGN KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`) REFERENCES `QRTZ_TRIGGERS` (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Quartz Cron 트리거 정보';


-- maestro.QRTZ_SIMPLE_TRIGGERS definition

CREATE OR REPLACE TABLE `QRTZ_SIMPLE_TRIGGERS` (
  `SCHED_NAME` varchar(120) NOT NULL COMMENT '스케줄러 이름',
  `TRIGGER_NAME` varchar(200) NOT NULL COMMENT '트리거 이름',
  `TRIGGER_GROUP` varchar(200) NOT NULL COMMENT '트리거 그룹',
  `REPEAT_COUNT` int(11) NOT NULL COMMENT '반복 횟수',
  `REPEAT_INTERVAL` bigint(13) NOT NULL COMMENT '반복 간격',
  `TIMES_TRIGGERED` int(11) NOT NULL COMMENT '트리거 실행 횟수',
  PRIMARY KEY (`SCHED_NAME`,`TRIGGER_NAME`,`TRIGGER_GROUP`),
  CONSTRAINT `QRTZ_SIMPLE_TRIGGERS_ibfk_1` FOREIGN KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`) REFERENCES `QRTZ_TRIGGERS` (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Quartz Simple 트리거 정보';


-- maestro.QRTZ_SIMPROP_TRIGGERS definition

CREATE OR REPLACE TABLE `QRTZ_SIMPROP_TRIGGERS` (
  `SCHED_NAME` varchar(120) NOT NULL COMMENT '스케줄러 이름',
  `TRIGGER_NAME` varchar(200) NOT NULL COMMENT '트리거 이름',
  `TRIGGER_GROUP` varchar(200) NOT NULL COMMENT '트리거 그룹',
  `STR_PROP_1` varchar(512) DEFAULT NULL COMMENT '문자열 속성 1',
  `STR_PROP_2` varchar(512) DEFAULT NULL COMMENT '문자열 속성 2',
  `STR_PROP_3` varchar(512) DEFAULT NULL COMMENT '문자열 속성 3',
  `INT_PROP_1` int(11) DEFAULT NULL COMMENT '정수 속성 1',
  `INT_PROP_2` int(11) DEFAULT NULL COMMENT '정수 속성 2',
  `LONG_PROP_1` bigint(20) DEFAULT NULL COMMENT '긴 정수 속성 1',
  `LONG_PROP_2` bigint(20) DEFAULT NULL COMMENT '긴 정수 속성 2',
  `DEC_PROP_1` decimal(13,4) DEFAULT NULL COMMENT '실수 속성 1',
  `DEC_PROP_2` decimal(13,4) DEFAULT NULL COMMENT '실수 속성 2',
  `BOOL_PROP_1` varchar(1) DEFAULT NULL COMMENT '부울 속성 1',
  `BOOL_PROP_2` varchar(1) DEFAULT NULL COMMENT '부울 속성 2',
  PRIMARY KEY (`SCHED_NAME`,`TRIGGER_NAME`,`TRIGGER_GROUP`),
  CONSTRAINT `QRTZ_SIMPROP_TRIGGERS_ibfk_1` FOREIGN KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`) REFERENCES `QRTZ_TRIGGERS` (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Quartz Simple 속성 트리거 정보';


-- maestro.MSTR_ADMIN_FOLDER_ROLE definition

CREATE OR REPLACE TABLE `MSTR_ADMIN_FOLDER_ROLE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `folder_id` varchar(36) NOT NULL DEFAULT uuid(),
  `admin_in_folder_id` varchar(36) NOT NULL DEFAULT uuid(),
  `role_id` varchar(36) NOT NULL DEFAULT uuid(),
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_FOLDER_ROLE_1` (`folder_id`),
  KEY `FK_MSTR_ADMIN_IN_FOLDER_TO_MSTR_ADMIN_FOLDER_ROLE_1` (`admin_in_folder_id`),
  KEY `FK_MSTR_ROLE_TO_MSTR_ADMIN_FOLDER_ROLE_1` (`role_id`),
  CONSTRAINT `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_FOLDER_ROLE_1` FOREIGN KEY (`folder_id`) REFERENCES `MSTR_ADMIN_FOLDER` (`id`),
  CONSTRAINT `FK_MSTR_ADMIN_IN_FOLDER_TO_MSTR_ADMIN_FOLDER_ROLE_1` FOREIGN KEY (`admin_in_folder_id`) REFERENCES `MSTR_ADMIN_IN_FOLDER` (`id`),
  CONSTRAINT `FK_MSTR_ROLE_TO_MSTR_ADMIN_FOLDER_ROLE_1` FOREIGN KEY (`role_id`) REFERENCES `MSTR_ROLE` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_ADMIN_GROUP_FOLDER_ROLE definition

CREATE OR REPLACE TABLE `MSTR_ADMIN_GROUP_FOLDER_ROLE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `group_id` varchar(36) NOT NULL,
  `role_id` varchar(36) NOT NULL,
  `folder_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_GROUP_FOLDER_ROLE_1` (`folder_id`),
  KEY `FK_MSTR_ADMIN_GROUP_TO_MSTR_ADMIN_GROUP_FOLDER_ROLE_1` (`group_id`),
  KEY `FK_MSTR_ROLE_TO_MSTR_ADMIN_GROUP_FOLDER_ROLE_1` (`role_id`),
  CONSTRAINT `FK_MSTR_ADMIN_FOLDER_TO_MSTR_ADMIN_GROUP_FOLDER_ROLE_1` FOREIGN KEY (`folder_id`) REFERENCES `MSTR_ADMIN_FOLDER` (`id`),
  CONSTRAINT `FK_MSTR_ADMIN_GROUP_TO_MSTR_ADMIN_GROUP_FOLDER_ROLE_1` FOREIGN KEY (`group_id`) REFERENCES `MSTR_ADMIN_GROUP` (`id`),
  CONSTRAINT `FK_MSTR_ROLE_TO_MSTR_ADMIN_GROUP_FOLDER_ROLE_1` FOREIGN KEY (`role_id`) REFERENCES `MSTR_ROLE` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


-- maestro.MSTR_AUTHORITY_IN_ROLE definition

CREATE OR REPLACE TABLE `MSTR_AUTHORITY_IN_ROLE` (
  `id` varchar(36) NOT NULL DEFAULT uuid(),
  `role_id` varchar(36) NOT NULL,
  `authority_id` varchar(36) NOT NULL,
  `create_user_id` varchar(36) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `MSTR_AUTHORITY_IN_ROLE_MSTR_AUTHORITY_null_fk` (`authority_id`),
  KEY `MSTR_AUTHORITY_IN_ROLE_MSTR_ROLE_null_fk` (`role_id`),
  CONSTRAINT `MSTR_AUTHORITY_IN_ROLE_MSTR_AUTHORITY_null_fk` FOREIGN KEY (`authority_id`) REFERENCES `MSTR_AUTHORITY` (`id`),
  CONSTRAINT `MSTR_AUTHORITY_IN_ROLE_MSTR_ROLE_null_fk` FOREIGN KEY (`role_id`) REFERENCES `MSTR_ROLE` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;