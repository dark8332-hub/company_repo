CREATE DATABASE IF NOT EXISTS `drs`;

USE drs;

CREATE TABLE `optimize_host` (
  `id` bigint(20) NOT NULL,
  `plan_id` int(11) NOT NULL,
  `provider_id` varchar(100) NOT NULL,
  `host_name` varchar(100) NOT NULL,
  `running_vms` int(11) DEFAULT NULL,
  `host_used_cpu` int(11) DEFAULT NULL,
  `host_remain_cpu` int(11) DEFAULT NULL,
  `host_remain_memory` int(11) DEFAULT NULL,
  `host_used_memory` int(11) DEFAULT NULL,
  `timestamp` bigint(20) NOT NULL,
  PRIMARY KEY (`id`,`plan_id`,`provider_id`,`host_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `optimize_plan` (
  `id` bigint(20) NOT NULL,
  `plan_id` int(11) NOT NULL,
  `provider_id` varchar(100) NOT NULL,
  `status` enum('R','E') DEFAULT 'R',
  `final_status` enum('F','S') DEFAULT NULL,
  `stability_effect` double NOT NULL,
  `previous_stability` double NOT NULL,
  `migration_cost` double NOT NULL,
  `total_migration_count` int(11) NOT NULL,
  `timestamp` bigint(20) NOT NULL,
  PRIMARY KEY (`id`,`plan_id`,`provider_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `optimize_vm_detail` (
  `id` bigint(20) NOT NULL,
  `plan_id` int(11) NOT NULL,
  `sort_id` int(11) NOT NULL,
  `provider_id` varchar(100) NOT NULL,
  `status` enum('active','migrating','error') DEFAULT NULL,
  `from_host` varchar(100) DEFAULT NULL,
  `to_host` varchar(100) DEFAULT NULL,
  `migration_instance_uuid` varchar(100) DEFAULT NULL,
  `migration_instance_name` varchar(100) DEFAULT NULL,
  `final_status` enum('F','S') DEFAULT NULL,
  `migration_vm_cpu` int(11) NOT NULL,
  `migration_vm_memory` int(11) NOT NULL,
  `timestamp` bigint(20) NOT NULL,
  PRIMARY KEY (`id`,`plan_id`,`sort_id`,`provider_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;