CREATE DATABASE IF NOT EXISTS `contrabass` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */;

USE contrabass;

CREATE TABLE IF NOT EXISTS `cb_backup_node_info`
(
    `id`          bigint(20)   NOT NULL AUTO_INCREMENT,
    `backup_type` varchar(255) NOT NULL,
    `node_ip`     varchar(255) NOT NULL,
    `deleted`     tinyint(1)            DEFAULT 0,
    `created_at`  timestamp    NOT NULL DEFAULT current_timestamp(),
    `updated_at`  timestamp    NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE = InnoDB
  AUTO_INCREMENT = 4
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;


-- contrabass.cb_backup_schedule definition

CREATE TABLE IF NOT EXISTS `cb_backup_schedule`
(
    `id`                    bigint(20)   NOT NULL AUTO_INCREMENT,
    `description`           text                  DEFAULT NULL,
    `schedule_cron`         varchar(255)          DEFAULT NULL,
    `backup_retention_days` int(11)               DEFAULT NULL,
    `enabled`               tinyint(1)   NOT NULL DEFAULT 1,
    `provider_id`           varchar(255)          DEFAULT NULL,
    `backup_type`           varchar(255) NOT NULL,
    `backup_mode`           varchar(255) NOT NULL,
    `created_at`            timestamp    NOT NULL DEFAULT current_timestamp(),
    `updated_at`            timestamp    NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE = InnoDB
  AUTO_INCREMENT = 3
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;


-- contrabass.cb_backup_job_history definition

CREATE TABLE IF NOT EXISTS `cb_backup_job_history`
(
    `id`                    bigint(20)  NOT NULL AUTO_INCREMENT,
    `job_id`                bigint(20)       DEFAULT NULL,
    `schedule_id`           bigint(20)       DEFAULT NULL,
    `provider_id`           varchar(255)     DEFAULT NULL,
    `backup_type`           varchar(255)     DEFAULT NULL,
    `backup_status`         varchar(50) NOT NULL,
    `error_message`         text             DEFAULT NULL,
    `node_ip`               varchar(255)     DEFAULT NULL,
    `scheduled_backup_time` timestamp   NULL DEFAULT NULL,
    `created_at`            timestamp   NULL DEFAULT current_timestamp(),
    `updated_at`            timestamp   NOT NULL,
    PRIMARY KEY (`id`),
    KEY `schedule_id` (`schedule_id`),
    CONSTRAINT `cb_backup_job_history_ibfk_1` FOREIGN KEY (`schedule_id`) REFERENCES `cb_backup_schedule` (`id`) ON DELETE CASCADE
) ENGINE = InnoDB
  AUTO_INCREMENT = 49
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;


-- contrabass.cb_backup_job_status definition

CREATE TABLE IF NOT EXISTS `cb_backup_job_status`
(
    `id`                 bigint(20)   NOT NULL AUTO_INCREMENT,
    `backup_schedule_id` bigint(20)            DEFAULT NULL,
    `provider_id`        varchar(255) NOT NULL,
    `backup_type`        varchar(255) NOT NULL,
    `first_backup_time`  timestamp    NOT NULL,
    `last_backup_time`   timestamp    NOT NULL,
    `backup_status`      varchar(50)  NOT NULL,
    `error_message`      text                  DEFAULT NULL,
    `created_at`         timestamp    NOT NULL DEFAULT current_timestamp(),
    `updated_at`         timestamp    NOT NULL,
    PRIMARY KEY (`id`),
    KEY `backup_schedule_id` (`backup_schedule_id`),
    CONSTRAINT `cb_backup_job_status_ibfk_1` FOREIGN KEY (`backup_schedule_id`) REFERENCES `cb_backup_schedule` (`id`) ON DELETE CASCADE
) ENGINE = InnoDB
  AUTO_INCREMENT = 6
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;


-- contrabass.cb_backup_node_info_schedule definition

CREATE TABLE IF NOT EXISTS `cb_backup_node_info_schedule`
(
    `backup_node_info_id` bigint(20)            DEFAULT NULL,
    `backup_schedule_id`  bigint(20)            DEFAULT NULL,
    `backup_type`         varchar(255) NOT NULL,
    `created_at`          timestamp    NOT NULL DEFAULT current_timestamp(),
    KEY `backup_schedule_id` (`backup_schedule_id`),
    KEY `backup_node_info_id` (`backup_node_info_id`),
    CONSTRAINT `cb_backup_node_info_schedule_ibfk_1` FOREIGN KEY (`backup_schedule_id`) REFERENCES `cb_backup_schedule` (`id`) ON DELETE CASCADE,
    CONSTRAINT `cb_backup_node_info_schedule_ibfk_2` FOREIGN KEY (`backup_node_info_id`) REFERENCES `cb_backup_node_info` (`id`) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- Create volume_backup_history table if it does not exist
DROP TABLE IF EXISTS cb_volume_backup_history;
CREATE TABLE IF NOT EXISTS `cb_volume_backup_history`
(
    `id`          bigint(20) NOT NULL AUTO_INCREMENT,
    `backup_id`   varchar(255)  DEFAULT NULL,
    `volume_id`   varchar(255)  DEFAULT NULL,
    `schedule_id` bigint(20)    DEFAULT NULL,
    `fail_reason` varchar(1024) DEFAULT NULL,
    `created_at`  timestamp  NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

# ALTER TABLE `cb_volume_backup_history`
#     DROP PRIMARY KEY, -- 기존의 PK 제거
#     ADD COLUMN IF NOT EXISTS `id` bigint(20) NOT NULL AUTO_INCREMENT FIRST, -- 새로운 PK 추가
#     MODIFY COLUMN `backup_id` varchar(255) DEFAULT NULL, -- 새로운 PK 추가
#     MODIFY COLUMN `schedule_id` bigint(20) DEFAULT NULL, -- 새로운 PK 추가
#     ADD COLUMN IF NOT EXISTS `fail_reason` varchar(1024) DEFAULT NULL,
#     ADD COLUMN IF NOT EXISTS `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
#     ADD PRIMARY KEY (`id`);

-- Create volume_backup_schedule table if it does not exist
CREATE TABLE IF NOT EXISTS `cb_volume_backup_schedule`
(
    `id`               bigint(20)   NOT NULL AUTO_INCREMENT,
    `volume_id`        varchar(255) NOT NULL,
    `schedule_cron`    varchar(255) NOT NULL,
    `enabled`          tinyint(1)   NOT NULL,
    `force_back_up`    tinyint(1)        DEFAULT NULL,
    `incremental`      tinyint(1)        DEFAULT NULL,
    `backup_name`      varchar(255)      DEFAULT NULL,
    `description`      text              DEFAULT NULL,
    `container`        varchar(255)      DEFAULT NULL,
    `snapshot_id`      varchar(255)      DEFAULT NULL,
    `project_id`       varchar(255)      DEFAULT NULL,
    `last_backup_time` timestamp    NULL DEFAULT NULL,
    `backup_status`    tinyint(1)        DEFAULT NULL,
    `created_at`       timestamp    NOT NULL,
    `updated_at`       timestamp    NOT NULL,
    `deleted_at`       timestamp    NULL DEFAULT NULL,
    `provider_id`      varchar(255)      DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE = InnoDB
  AUTO_INCREMENT = 96
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- contrabass.QRTZ_FIRED_TRIGGERS definition

CREATE TABLE IF NOT EXISTS `QRTZ_FIRED_TRIGGERS`
(
    `SCHED_NAME`        varchar(120) NOT NULL,
    `ENTRY_ID`          varchar(95)  NOT NULL,
    `TRIGGER_NAME`      varchar(190) NOT NULL,
    `TRIGGER_GROUP`     varchar(190) NOT NULL,
    `INSTANCE_NAME`     varchar(190) NOT NULL,
    `FIRED_TIME`        bigint(13)   NOT NULL,
    `SCHED_TIME`        bigint(13)   NOT NULL,
    `PRIORITY`          int(11)      NOT NULL,
    `STATE`             varchar(16)  NOT NULL,
    `JOB_NAME`          varchar(190) DEFAULT NULL,
    `JOB_GROUP`         varchar(190) DEFAULT NULL,
    `IS_NONCONCURRENT`  varchar(1)   DEFAULT NULL,
    `REQUESTS_RECOVERY` varchar(1)   DEFAULT NULL,
    PRIMARY KEY (`SCHED_NAME`, `ENTRY_ID`),
    KEY `IDX_QRTZ_FT_TRIG_INST_NAME` (`SCHED_NAME`, `INSTANCE_NAME`),
    KEY `IDX_QRTZ_FT_INST_JOB_REQ_RCVRY` (`SCHED_NAME`, `INSTANCE_NAME`, `REQUESTS_RECOVERY`),
    KEY `IDX_QRTZ_FT_J_G` (`SCHED_NAME`, `JOB_NAME`, `JOB_GROUP`),
    KEY `IDX_QRTZ_FT_JG` (`SCHED_NAME`, `JOB_GROUP`),
    KEY `IDX_QRTZ_FT_T_G` (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`),
    KEY `IDX_QRTZ_FT_TG` (`SCHED_NAME`, `TRIGGER_GROUP`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;


-- contrabass.QRTZ_JOB_DETAILS definition

CREATE TABLE IF NOT EXISTS `QRTZ_JOB_DETAILS`
(
    `SCHED_NAME`        varchar(120) NOT NULL,
    `JOB_NAME`          varchar(190) NOT NULL,
    `JOB_GROUP`         varchar(190) NOT NULL,
    `DESCRIPTION`       varchar(250) DEFAULT NULL,
    `JOB_CLASS_NAME`    varchar(250) NOT NULL,
    `IS_DURABLE`        varchar(1)   NOT NULL,
    `IS_NONCONCURRENT`  varchar(1)   NOT NULL,
    `IS_UPDATE_DATA`    varchar(1)   NOT NULL,
    `REQUESTS_RECOVERY` varchar(1)   NOT NULL,
    `JOB_DATA`          blob         DEFAULT NULL,
    PRIMARY KEY (`SCHED_NAME`, `JOB_NAME`, `JOB_GROUP`),
    KEY `IDX_QRTZ_J_REQ_RECOVERY` (`SCHED_NAME`, `REQUESTS_RECOVERY`),
    KEY `IDX_QRTZ_J_GRP` (`SCHED_NAME`, `JOB_GROUP`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;


-- contrabass.QRTZ_LOCKS definition

CREATE TABLE IF NOT EXISTS `QRTZ_LOCKS`
(
    `SCHED_NAME` varchar(120) NOT NULL,
    `LOCK_NAME`  varchar(40)  NOT NULL,
    PRIMARY KEY (`SCHED_NAME`, `LOCK_NAME`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;


-- contrabass.QRTZ_PAUSED_TRIGGER_GRPS definition

CREATE TABLE IF NOT EXISTS `QRTZ_PAUSED_TRIGGER_GRPS`
(
    `SCHED_NAME`    varchar(120) NOT NULL,
    `TRIGGER_GROUP` varchar(190) NOT NULL,
    PRIMARY KEY (`SCHED_NAME`, `TRIGGER_GROUP`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;


-- contrabass.QRTZ_SCHEDULER_STATE definition

CREATE TABLE IF NOT EXISTS `QRTZ_SCHEDULER_STATE`
(
    `SCHED_NAME`        varchar(120) NOT NULL,
    `INSTANCE_NAME`     varchar(190) NOT NULL,
    `LAST_CHECKIN_TIME` bigint(13)   NOT NULL,
    `CHECKIN_INTERVAL`  bigint(13)   NOT NULL,
    PRIMARY KEY (`SCHED_NAME`, `INSTANCE_NAME`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;


-- contrabass.QRTZ_TRIGGERS definition

CREATE TABLE IF NOT EXISTS `QRTZ_TRIGGERS`
(
    `SCHED_NAME`     varchar(120) NOT NULL,
    `TRIGGER_NAME`   varchar(190) NOT NULL,
    `TRIGGER_GROUP`  varchar(190) NOT NULL,
    `JOB_NAME`       varchar(190) NOT NULL,
    `JOB_GROUP`      varchar(190) NOT NULL,
    `DESCRIPTION`    varchar(250) DEFAULT NULL,
    `NEXT_FIRE_TIME` bigint(13)   DEFAULT NULL,
    `PREV_FIRE_TIME` bigint(13)   DEFAULT NULL,
    `PRIORITY`       int(11)      DEFAULT NULL,
    `TRIGGER_STATE`  varchar(16)  NOT NULL,
    `TRIGGER_TYPE`   varchar(8)   NOT NULL,
    `START_TIME`     bigint(13)   NOT NULL,
    `END_TIME`       bigint(13)   DEFAULT NULL,
    `CALENDAR_NAME`  varchar(190) DEFAULT NULL,
    `MISFIRE_INSTR`  smallint(2)  DEFAULT NULL,
    `JOB_DATA`       blob         DEFAULT NULL,
    PRIMARY KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`),
    KEY `IDX_QRTZ_T_J` (`SCHED_NAME`, `JOB_NAME`, `JOB_GROUP`),
    KEY `IDX_QRTZ_T_JG` (`SCHED_NAME`, `JOB_GROUP`),
    KEY `IDX_QRTZ_T_C` (`SCHED_NAME`, `CALENDAR_NAME`),
    KEY `IDX_QRTZ_T_G` (`SCHED_NAME`, `TRIGGER_GROUP`),
    KEY `IDX_QRTZ_T_STATE` (`SCHED_NAME`, `TRIGGER_STATE`),
    KEY `IDX_QRTZ_T_N_STATE` (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`, `TRIGGER_STATE`),
    KEY `IDX_QRTZ_T_N_G_STATE` (`SCHED_NAME`, `TRIGGER_GROUP`, `TRIGGER_STATE`),
    KEY `IDX_QRTZ_T_NEXT_FIRE_TIME` (`SCHED_NAME`, `NEXT_FIRE_TIME`),
    KEY `IDX_QRTZ_T_NFT_ST` (`SCHED_NAME`, `TRIGGER_STATE`, `NEXT_FIRE_TIME`),
    KEY `IDX_QRTZ_T_NFT_MISFIRE` (`SCHED_NAME`, `MISFIRE_INSTR`, `NEXT_FIRE_TIME`),
    KEY `IDX_QRTZ_T_NFT_ST_MISFIRE` (`SCHED_NAME`, `MISFIRE_INSTR`, `NEXT_FIRE_TIME`, `TRIGGER_STATE`),
    KEY `IDX_QRTZ_T_NFT_ST_MISFIRE_GRP` (`SCHED_NAME`, `MISFIRE_INSTR`, `NEXT_FIRE_TIME`, `TRIGGER_GROUP`,
                                         `TRIGGER_STATE`),
    CONSTRAINT `QRTZ_TRIGGERS_ibfk_1` FOREIGN KEY (`SCHED_NAME`, `JOB_NAME`, `JOB_GROUP`) REFERENCES `QRTZ_JOB_DETAILS` (`SCHED_NAME`, `JOB_NAME`, `JOB_GROUP`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;


-- contrabass.QRTZ_BLOB_TRIGGERS definition

CREATE TABLE IF NOT EXISTS `QRTZ_BLOB_TRIGGERS`
(
    `SCHED_NAME`    varchar(120) NOT NULL,
    `TRIGGER_NAME`  varchar(190) NOT NULL,
    `TRIGGER_GROUP` varchar(190) NOT NULL,
    `BLOB_DATA`     blob DEFAULT NULL,
    PRIMARY KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`),
    KEY `SCHED_NAME` (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`),
    CONSTRAINT `QRTZ_BLOB_TRIGGERS_ibfk_1` FOREIGN KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`) REFERENCES `QRTZ_TRIGGERS` (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;


-- contrabass.QRTZ_CRON_TRIGGERS definition

CREATE TABLE IF NOT EXISTS `QRTZ_CRON_TRIGGERS`
(
    `SCHED_NAME`      varchar(120) NOT NULL,
    `TRIGGER_NAME`    varchar(190) NOT NULL,
    `TRIGGER_GROUP`   varchar(190) NOT NULL,
    `CRON_EXPRESSION` varchar(120) NOT NULL,
    `TIME_ZONE_ID`    varchar(80) DEFAULT NULL,
    PRIMARY KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`),
    CONSTRAINT `QRTZ_CRON_TRIGGERS_ibfk_1` FOREIGN KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`) REFERENCES `QRTZ_TRIGGERS` (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;


-- contrabass.QRTZ_SIMPLE_TRIGGERS definition

CREATE TABLE IF NOT EXISTS `QRTZ_SIMPLE_TRIGGERS`
(
    `SCHED_NAME`      varchar(120) NOT NULL,
    `TRIGGER_NAME`    varchar(190) NOT NULL,
    `TRIGGER_GROUP`   varchar(190) NOT NULL,
    `REPEAT_COUNT`    bigint(7)    NOT NULL,
    `REPEAT_INTERVAL` bigint(12)   NOT NULL,
    `TIMES_TRIGGERED` bigint(10)   NOT NULL,
    PRIMARY KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`),
    CONSTRAINT `QRTZ_SIMPLE_TRIGGERS_ibfk_1` FOREIGN KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`) REFERENCES `QRTZ_TRIGGERS` (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;


-- contrabass.QRTZ_SIMPROP_TRIGGERS definition

CREATE TABLE IF NOT EXISTS `QRTZ_SIMPROP_TRIGGERS`
(
    `SCHED_NAME`    varchar(120) NOT NULL,
    `TRIGGER_NAME`  varchar(190) NOT NULL,
    `TRIGGER_GROUP` varchar(190) NOT NULL,
    `STR_PROP_1`    varchar(512)   DEFAULT NULL,
    `STR_PROP_2`    varchar(512)   DEFAULT NULL,
    `STR_PROP_3`    varchar(512)   DEFAULT NULL,
    `INT_PROP_1`    int(11)        DEFAULT NULL,
    `INT_PROP_2`    int(11)        DEFAULT NULL,
    `LONG_PROP_1`   bigint(20)     DEFAULT NULL,
    `LONG_PROP_2`   bigint(20)     DEFAULT NULL,
    `DEC_PROP_1`    decimal(13, 4) DEFAULT NULL,
    `DEC_PROP_2`    decimal(13, 4) DEFAULT NULL,
    `BOOL_PROP_1`   varchar(1)     DEFAULT NULL,
    `BOOL_PROP_2`   varchar(1)     DEFAULT NULL,
    PRIMARY KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`),
    CONSTRAINT `QRTZ_SIMPROP_TRIGGERS_ibfk_1` FOREIGN KEY (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`) REFERENCES `QRTZ_TRIGGERS` (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;
