CREATE DATABASE IF NOT EXISTS `cloud_service` ;

USE `cloud_service`;

-- cloud_service.MSTR_API_STATISTICS definition

CREATE OR REPLACE TABLE cloud_service.`MSTR_API_STATISTICS` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `provider_type` int(11) DEFAULT NULL,
  `endpoint_id` varchar(36) DEFAULT NULL,
  `api_path` varchar(127) DEFAULT NULL,
  `http_status` int(11) DEFAULT NULL,
  `http_method` varchar(8) DEFAULT NULL,
  `user_id` varchar(36) DEFAULT NULL,
  `workspace_id` varchar(36) DEFAULT NULL,
  `time` timestamp NULL DEFAULT NULL,
  `is_admin` int(11) DEFAULT NULL,
  `type_name` varchar(255) DEFAULT NULL,
  `ip` varchar(255) DEFAULT NULL,
  `content` varchar(255) DEFAULT NULL,
  `request_body` text DEFAULT NULL,
  `response_body` text DEFAULT NULL,
  `params` text DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=991 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;