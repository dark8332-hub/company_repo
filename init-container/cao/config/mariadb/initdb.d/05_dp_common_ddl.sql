--create database dp_common;
CREATE DATABASE IF NOT EXISTS `dp_common` ;

USE `dp_common`;

CREATE TABLE `cm_provider_type` (
  `id` bigint(20) NOT NULL,
  `name` varchar(512) DEFAULT NULL,
  `description` varchar(2048) DEFAULT NULL,
  `delete_yn` char(1) DEFAULT NULL,
  `reg_dt` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cm_provider` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `provider_type_id` bigint(20) NOT NULL,
  `name` varchar(512) DEFAULT NULL,
  `description` varchar(2048) DEFAULT NULL,
  `uuid` varchar(512) DEFAULT NULL,
  `delete_yn` char(1) DEFAULT NULL,
  `reg_dt` timestamp NULL DEFAULT NULL,
  `mod_dt` timestamp NULL DEFAULT NULL,
  `del_dt` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`,`provider_type_id`),
  UNIQUE KEY `UK_cm_provider_provider_type_uuid` (`provider_type_id`, `uuid`),
  KEY `FK_cm_provider_type_TO_cm_provider_1` (`provider_type_id`),
  CONSTRAINT `FK_cm_provider_type_TO_cm_provider_1` FOREIGN KEY (`provider_type_id`) REFERENCES `cm_provider_type` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cm_resource_type_kind` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(512) DEFAULT NULL,
  `description` varchar(2048) DEFAULT NULL,
  `delete_yn` char(1) DEFAULT NULL,
  `reg_dt` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cm_resource_type` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `resource_type_kind_id` bigint(20) NOT NULL,
  `name` varchar(512) DEFAULT NULL,
  `description` varchar(2048) DEFAULT NULL,
  `delete_yn` char(1) DEFAULT NULL,
  `reg_dt` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`,`resource_type_kind_id`),
  KEY `FK_cm_resource_type_kind_TO_cm_resource_type_1` (`resource_type_kind_id`),
  CONSTRAINT `FK_cm_resource_type_kind_TO_cm_resource_type_1` FOREIGN KEY (`resource_type_kind_id`) REFERENCES `cm_resource_type_kind` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cm_resource` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `provider_id` bigint(20) NOT NULL,
  `resource_type_id` bigint(20) NOT NULL,
  `uuid` varchar(512) DEFAULT NULL,
  `resource_name` varchar(256) DEFAULT NULL,
  `resource_desc` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `cm_resource_unique` (`provider_id`,`resource_type_id`,`uuid`),
  KEY `FK_cm_provider_TO_cm_resource_1` (`provider_id`),
  KEY `FK_cm_resource_type_TO_cm_resource_1` (`resource_type_id`),
  CONSTRAINT `FK_cm_resource_type_TO_cm_resource_1` FOREIGN KEY (`resource_type_id`) REFERENCES `cm_resource_type` (`id`),
  CONSTRAINT `FK_cm_provider_TO_cm_resource_1` FOREIGN KEY (`provider_id`) REFERENCES `cm_provider` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cm_resource_attr` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `resource_id` bigint(20) NOT NULL,
  `key` varchar(512) DEFAULT NULL,
  `value` longtext DEFAULT NULL,
  `description` varchar(2048) DEFAULT NULL,
  `value_type` varchar(12) DEFAULT NULL,
  PRIMARY KEY (`id`,`resource_id`),
  UNIQUE KEY `cm_resource_attr_UN` (`resource_id`,`key`),
  CONSTRAINT `FK_cm_resource_TO_cm_resource_attr_1` FOREIGN KEY (`resource_id`) REFERENCES `cm_resource` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cm_resource_history` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `provider_id` bigint(20) NOT NULL,
  `resource_type_id` bigint(20) NOT NULL,
  `uuid` varchar(512) DEFAULT NULL,
  `resource_name` varchar(256) DEFAULT NULL,
  `resource_desc` varchar(256) DEFAULT NULL,
  `edit_user` varchar(128) DEFAULT NULL,
  `execute_kind` varchar(32) DEFAULT NULL,
  `execute_dt` datetime DEFAULT NULL,
  PRIMARY KEY (`id`,`provider_id`,`resource_type_id`),
  KEY `FK_cm_provider_TO_cm_resource_history_1` (`provider_id`),
  KEY `FK_cm_resource_type_TO_cm_resource_history_1` (`resource_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cm_resource_attr_history` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `uuid` varchar(512) DEFAULT NULL,
  `key` varchar(512) DEFAULT NULL,
  `value` longtext DEFAULT NULL,
  `description` varchar(2048) DEFAULT NULL,
  `value_type` varchar(12) DEFAULT NULL,
  `edit_user` varchar(128) DEFAULT NULL,
  `execute_kind` varchar(32) DEFAULT NULL,
  `execute_dt` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cm_resource_relation` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `resource_id` bigint(20) NOT NULL,
  `parent_resource_id` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_resource_relation` (`resource_id`, `parent_resource_id`),
  KEY `FK_cm_resource_TO_cm_resource_relation_1` (`resource_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cm_config_type` (
  `id` bigint(20) NOT NULL,
  `name` varchar(512) DEFAULT NULL,
  `description` varchar(2048) DEFAULT NULL,
  `delete_yn` char(1) DEFAULT NULL,
  `reg_dt` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cm_config` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `provider_id` bigint(20) NOT NULL,
  `config_type_id` bigint(20) NOT NULL,
  `uuid` varchar(128) DEFAULT NULL,
  `config_name` varchar(256) DEFAULT NULL,
  `config_desc` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `cm_config_unique` (`provider_id`,`config_type_id`,`uuid`),
  KEY `FK_cm_config_type_TO_cm_config_1` (`config_type_id`),
  KEY `FK_cm_provider_TO_cm_config` (`provider_id`),
  CONSTRAINT `FK_cm_config_type_TO_cm_config_1` FOREIGN KEY (`config_type_id`) 
    REFERENCES `cm_config_type` (`id`),
  CONSTRAINT `FK_cm_provider_TO_cm_config` FOREIGN KEY (`provider_id`) 
    REFERENCES `cm_provider` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE `cm_config_attr` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `config_id` bigint(20) NOT NULL,
  `key` varchar(512) DEFAULT NULL,
  `value` longtext DEFAULT NULL,
  `description` varchar(2048) DEFAULT NULL,
  `value_type` varchar(12) DEFAULT NULL,
  PRIMARY KEY (`id`,`config_id`),
  UNIQUE KEY `cm_config_attr_UN` (`config_id`,`key`),
  CONSTRAINT `FK_cm_config_TO_cm_config_attr_1` FOREIGN KEY (`config_id`) REFERENCES `cm_config` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
