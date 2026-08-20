-- MariaDB dump 10.19  Distrib 10.11.6-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: keycloak
-- ------------------------------------------------------
-- Server version       10.11.6-MariaDB-1:10.11.6+maria~ubu2204

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `keycloak`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `keycloak` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci */;

USE `keycloak`;

--
-- Table structure for table `ADMIN_EVENT_ENTITY`
--

DROP TABLE IF EXISTS `ADMIN_EVENT_ENTITY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ADMIN_EVENT_ENTITY` (
  `ID` varchar(36) NOT NULL,
  `ADMIN_EVENT_TIME` bigint(20) DEFAULT NULL,
  `REALM_ID` varchar(255) DEFAULT NULL,
  `OPERATION_TYPE` varchar(255) DEFAULT NULL,
  `AUTH_REALM_ID` varchar(255) DEFAULT NULL,
  `AUTH_CLIENT_ID` varchar(255) DEFAULT NULL,
  `AUTH_USER_ID` varchar(255) DEFAULT NULL,
  `IP_ADDRESS` varchar(255) DEFAULT NULL,
  `RESOURCE_PATH` text DEFAULT NULL,
  `REPRESENTATION` text DEFAULT NULL,
  `ERROR` varchar(255) DEFAULT NULL,
  `RESOURCE_TYPE` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_ADMIN_EVENT_TIME` (`REALM_ID`,`ADMIN_EVENT_TIME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ADMIN_EVENT_ENTITY`
--

LOCK TABLES `ADMIN_EVENT_ENTITY` WRITE;
/*!40000 ALTER TABLE `ADMIN_EVENT_ENTITY` DISABLE KEYS */;
/*!40000 ALTER TABLE `ADMIN_EVENT_ENTITY` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ASSOCIATED_POLICY`
--

DROP TABLE IF EXISTS `ASSOCIATED_POLICY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ASSOCIATED_POLICY` (
  `POLICY_ID` varchar(36) NOT NULL,
  `ASSOCIATED_POLICY_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`POLICY_ID`,`ASSOCIATED_POLICY_ID`),
  KEY `IDX_ASSOC_POL_ASSOC_POL_ID` (`ASSOCIATED_POLICY_ID`),
  CONSTRAINT `FK_FRSR5S213XCX4WNKOG82SSRFY` FOREIGN KEY (`ASSOCIATED_POLICY_ID`) REFERENCES `RESOURCE_SERVER_POLICY` (`ID`),
  CONSTRAINT `FK_FRSRPAS14XCX4WNKOG82SSRFY` FOREIGN KEY (`POLICY_ID`) REFERENCES `RESOURCE_SERVER_POLICY` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ASSOCIATED_POLICY`
--

LOCK TABLES `ASSOCIATED_POLICY` WRITE;
/*!40000 ALTER TABLE `ASSOCIATED_POLICY` DISABLE KEYS */;
/*!40000 ALTER TABLE `ASSOCIATED_POLICY` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `AUTHENTICATION_EXECUTION`
--

DROP TABLE IF EXISTS `AUTHENTICATION_EXECUTION`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AUTHENTICATION_EXECUTION` (
  `ID` varchar(36) NOT NULL,
  `ALIAS` varchar(255) DEFAULT NULL,
  `AUTHENTICATOR` varchar(36) DEFAULT NULL,
  `REALM_ID` varchar(36) DEFAULT NULL,
  `FLOW_ID` varchar(36) DEFAULT NULL,
  `REQUIREMENT` int(11) DEFAULT NULL,
  `PRIORITY` int(11) DEFAULT NULL,
  `AUTHENTICATOR_FLOW` bit(1) NOT NULL DEFAULT b'0',
  `AUTH_FLOW_ID` varchar(36) DEFAULT NULL,
  `AUTH_CONFIG` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_AUTH_EXEC_REALM_FLOW` (`REALM_ID`,`FLOW_ID`),
  KEY `IDX_AUTH_EXEC_FLOW` (`FLOW_ID`),
  CONSTRAINT `FK_AUTH_EXEC_FLOW` FOREIGN KEY (`FLOW_ID`) REFERENCES `AUTHENTICATION_FLOW` (`ID`),
  CONSTRAINT `FK_AUTH_EXEC_REALM` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `AUTHENTICATION_EXECUTION`
--

LOCK TABLES `AUTHENTICATION_EXECUTION` WRITE;
/*!40000 ALTER TABLE `AUTHENTICATION_EXECUTION` DISABLE KEYS */;
INSERT INTO `AUTHENTICATION_EXECUTION` VALUES
('0127eafe-cb2d-4584-8812-ece65f0feada',NULL,'reset-credential-email','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','a1cbf9b5-224d-4e1e-a6bf-d780ec5a49a2',0,20,'\0',NULL,NULL),
('04f1335a-2d31-4074-a2d6-5e8b266d33a6',NULL,'conditional-user-configured','dab18c5a-b240-4256-b8a9-31247dda96ac','c961857a-9867-47ba-8f6c-7c3d52a303cc',0,10,'\0',NULL,NULL),
('0688cfb3-7d5e-4e9e-b6c7-7165c17e73cd',NULL,'conditional-user-configured','dab18c5a-b240-4256-b8a9-31247dda96ac','5fc7960f-4854-424a-9fad-c43840b87c0c',0,10,'\0',NULL,NULL),
('0762c76b-56dc-4422-af01-a1af61c091e9',NULL,'auth-otp-form','dab18c5a-b240-4256-b8a9-31247dda96ac','d4059983-21af-4295-b5f1-a3e5222f8399',0,20,'\0',NULL,NULL),
('1179e0c6-816d-4c39-ada7-29f557b77503',NULL,NULL,'4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','23687fce-aeb8-45c0-8357-54f24e6b9f4e',2,20,'','c2303c15-6ebd-4513-960f-2faf7a69681b',NULL),
('13afa073-a1ad-4438-9bdd-c5d735bb67e7',NULL,'direct-grant-validate-username','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','12a7f999-a43e-473a-a05e-98f4d8587703',0,10,'\0',NULL,NULL),
('14c4fed1-b714-44af-b2c4-958c3ef4b5c3',NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','cae6de0e-18bf-4c98-9d4c-3a424521196c',2,20,'','b92334cb-ab49-46a3-af3a-bb9f8a893a06',NULL),
('175b0e58-a777-4b4b-9eff-ed4b1e136be4',NULL,'idp-username-password-form','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','c2303c15-6ebd-4513-960f-2faf7a69681b',0,10,'\0',NULL,NULL),
('1893294b-3c4b-4bcf-a6f8-e8ff9a171530',NULL,'registration-password-action','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','6ca473b1-f977-42fd-b50e-91a5377a6998',0,50,'\0',NULL,NULL),
('1a9bfa9f-995f-49d4-b8b8-0359fda9b11e',NULL,'auth-cookie','dab18c5a-b240-4256-b8a9-31247dda96ac','4efe3e4a-9c6c-4be6-9dec-15455a18d4e9',2,10,'\0',NULL,NULL),
('1c45e7f8-47dc-4839-ab83-62ff236e5122',NULL,'client-secret','dab18c5a-b240-4256-b8a9-31247dda96ac','da0c5ab5-14a6-40b7-b100-de65281caa75',2,10,'\0',NULL,NULL),
('1ccaabfa-73e7-4780-a5b7-4f6de82c57a4',NULL,'auth-username-password-form','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9bc23c86-ef45-4257-b3fe-56fc2c7850a1',0,10,'\0',NULL,NULL),
('2555b569-d2c2-447e-9291-c4ab67606549',NULL,'http-basic-authenticator','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','316d995f-e8bb-49d8-9bb6-e11a0ac074ea',0,10,'\0',NULL,NULL),
('2e43b124-146f-4db5-8166-52be45684024',NULL,'registration-recaptcha-action','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','6ca473b1-f977-42fd-b50e-91a5377a6998',3,60,'\0',NULL,NULL),
('2ecb4796-b6c9-4dd8-aba1-b0f35ae1b807',NULL,'direct-grant-validate-otp','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','fad0b67f-c9d3-4486-9422-ceb56ad7117d',0,20,'\0',NULL,NULL),
('30b7dc88-0d37-4b85-9ca8-22a891f5229c',NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','5696c659-6c77-458d-95a9-fd2b2563ee06',1,20,'','5fc7960f-4854-424a-9fad-c43840b87c0c',NULL),
('33ad83e7-d7c0-421f-b325-4be9d07cd29c',NULL,NULL,'4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','c9c521a4-c291-408b-9305-30c4b4be4edb',0,20,'','23687fce-aeb8-45c0-8357-54f24e6b9f4e',NULL),
('35a3533d-f60b-4cd4-9bc7-6476b60f6b44',NULL,'registration-user-creation','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','6ca473b1-f977-42fd-b50e-91a5377a6998',0,20,'\0',NULL,NULL),
('399c2437-8116-4ca7-89b3-e6260726d300',NULL,'auth-spnego','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','2a0c99b8-9d40-44d4-8aa9-c051fc797660',3,20,'\0',NULL,NULL),
('3cadb9a5-bbba-4e4a-b536-cf08ed4fddb9',NULL,'idp-create-user-if-unique','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','8a1fbbad-91cc-44f7-bde2-59013dd48ff7',2,10,'\0',NULL,'eac0cb1e-3175-4eaa-afdf-02c5d66a1108'),
('3d709536-66ee-477b-b762-b0174fedb423',NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','e1a7e6c0-6d27-49ef-a1a3-891ceb72661e',1,20,'','d4059983-21af-4295-b5f1-a3e5222f8399',NULL),
('4134d8b3-636d-44b4-95df-8b1af967d60a',NULL,'conditional-user-configured','dab18c5a-b240-4256-b8a9-31247dda96ac','d4059983-21af-4295-b5f1-a3e5222f8399',0,10,'\0',NULL,NULL),
('420795b2-c5e4-46bb-90fc-4ba7ee0b3469',NULL,'reset-otp','dab18c5a-b240-4256-b8a9-31247dda96ac','cb45781e-e70a-4fe2-9f2f-05420897c633',0,20,'\0',NULL,NULL),
('4eaed35a-1348-43fc-87cd-8622e429b602',NULL,'client-x509','dab18c5a-b240-4256-b8a9-31247dda96ac','da0c5ab5-14a6-40b7-b100-de65281caa75',2,40,'\0',NULL,NULL),
('4f61758f-c0e8-4f7e-9766-bacade79b51c',NULL,NULL,'4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','c2303c15-6ebd-4513-960f-2faf7a69681b',1,20,'','b576deeb-6294-440a-a391-1483bbd39989',NULL),
('503987de-8c17-4fc0-b23d-738411ecf48d',NULL,'registration-recaptcha-action','dab18c5a-b240-4256-b8a9-31247dda96ac','54e4dfb1-c8df-4e1b-8975-31f13cc503c9',3,60,'\0',NULL,NULL),
('557d227b-b9f9-48af-888e-0f4c30eab547',NULL,'direct-grant-validate-otp','dab18c5a-b240-4256-b8a9-31247dda96ac','c961857a-9867-47ba-8f6c-7c3d52a303cc',0,20,'\0',NULL,NULL),
('5a9ee0cb-4f41-4210-8003-6a1887572e2e',NULL,'direct-grant-validate-password','dab18c5a-b240-4256-b8a9-31247dda96ac','d2055d66-a9b7-4e74-9a10-e7ecfd9e8c1b',0,20,'\0',NULL,NULL),
('5bf350f4-4b02-4852-8fdc-8ca36c5df2e4',NULL,'registration-terms-and-conditions','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','6ca473b1-f977-42fd-b50e-91a5377a6998',3,70,'\0',NULL,NULL),
('5d2da27e-5298-407f-bdcf-2dbba4d0eae9',NULL,NULL,'4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','a1cbf9b5-224d-4e1e-a6bf-d780ec5a49a2',1,40,'','cccf5b19-8db8-4589-af41-02cfcd00fca8',NULL),
('5d805532-dbe9-4b35-915f-a767c3d25cbe',NULL,'reset-otp','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','cccf5b19-8db8-4589-af41-02cfcd00fca8',0,20,'\0',NULL,NULL),
('5e6fc1cf-121d-4531-9020-10815a164c02',NULL,'client-jwt','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','912298d3-c338-4ec1-8118-558c739617dd',2,20,'\0',NULL,NULL),
('62a45945-875e-45c3-80d4-7612694121a2',NULL,NULL,'4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9bc23c86-ef45-4257-b3fe-56fc2c7850a1',1,20,'','0402faae-c0a7-422e-b6fa-463f49d2d0e1',NULL),
('64a38a36-360e-4d31-bee2-71564a2ab1e2',NULL,'reset-credentials-choose-user','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','a1cbf9b5-224d-4e1e-a6bf-d780ec5a49a2',0,10,'\0',NULL,NULL),
('689ad2aa-62b9-41c3-ba15-964a87a26c73',NULL,'conditional-user-configured','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','fad0b67f-c9d3-4486-9422-ceb56ad7117d',0,10,'\0',NULL,NULL),
('6cee9929-0137-41ad-833e-c15e3bf2e593',NULL,'idp-email-verification','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','23687fce-aeb8-45c0-8357-54f24e6b9f4e',2,10,'\0',NULL,NULL),
('6d92427f-5aad-4e15-af2f-fb63d9d2ce51',NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','d2055d66-a9b7-4e74-9a10-e7ecfd9e8c1b',1,30,'','c961857a-9867-47ba-8f6c-7c3d52a303cc',NULL),
('6e9b7dad-1109-42c4-8bf4-d4193148ce22',NULL,'registration-password-action','dab18c5a-b240-4256-b8a9-31247dda96ac','54e4dfb1-c8df-4e1b-8975-31f13cc503c9',0,50,'\0',NULL,NULL),
('6fb579b3-9a61-48a3-9834-e2a5bdf49b56',NULL,'client-secret','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','912298d3-c338-4ec1-8118-558c739617dd',2,10,'\0',NULL,NULL),
('7381994e-18d5-4247-9f7b-f40b430962c4',NULL,'reset-password','dab18c5a-b240-4256-b8a9-31247dda96ac','0d78c1a6-232b-44c0-ab89-02c34086e849',0,30,'\0',NULL,NULL),
('78a8aadd-8cb7-4411-957b-ba53a621305d',NULL,'direct-grant-validate-username','dab18c5a-b240-4256-b8a9-31247dda96ac','d2055d66-a9b7-4e74-9a10-e7ecfd9e8c1b',0,10,'\0',NULL,NULL),
('88f5c09b-0cd7-480e-9f86-01846a979bb4',NULL,'auth-cookie','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','2a0c99b8-9d40-44d4-8aa9-c051fc797660',2,10,'\0',NULL,NULL),
('894c35eb-ea5b-42a4-82bf-76b4b1a3517f',NULL,'idp-username-password-form','dab18c5a-b240-4256-b8a9-31247dda96ac','5696c659-6c77-458d-95a9-fd2b2563ee06',0,10,'\0',NULL,NULL),
('8a010d31-f8d6-456e-bed8-3307c713f43e',NULL,'auth-otp-form','dab18c5a-b240-4256-b8a9-31247dda96ac','5fc7960f-4854-424a-9fad-c43840b87c0c',0,20,'\0',NULL,NULL),
('8cb8894f-fe1a-4694-8e5f-28f65c21bf42',NULL,NULL,'4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','2a0c99b8-9d40-44d4-8aa9-c051fc797660',2,30,'','9bc23c86-ef45-4257-b3fe-56fc2c7850a1',NULL),
('8d0f4b19-2185-41f1-bb6d-3a8ff9704ff6',NULL,'idp-confirm-link','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','c9c521a4-c291-408b-9305-30c4b4be4edb',0,10,'\0',NULL,NULL),
('8e65b5c0-bdcc-498e-a6a2-3f3e7d4b98d2',NULL,'reset-password','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','a1cbf9b5-224d-4e1e-a6bf-d780ec5a49a2',0,30,'\0',NULL,NULL),
('8e7fde94-39fe-4eeb-ac6e-d92a411ecf2e',NULL,NULL,'4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','8283dc5d-6f9a-457a-be33-4004a49e013b',0,20,'','8a1fbbad-91cc-44f7-bde2-59013dd48ff7',NULL),
('90144a3d-0a31-4f50-a2ba-647446c09442',NULL,'conditional-user-configured','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','b576deeb-6294-440a-a391-1483bbd39989',0,10,'\0',NULL,NULL),
('929a1a68-0dbe-471d-bddb-42c27646a21d',NULL,'conditional-user-configured','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','0402faae-c0a7-422e-b6fa-463f49d2d0e1',0,10,'\0',NULL,NULL),
('93f46142-e767-41bd-863e-31c925d0fe91',NULL,'conditional-user-configured','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','cccf5b19-8db8-4589-af41-02cfcd00fca8',0,10,'\0',NULL,NULL),
('99736a87-4efc-4974-8a6c-40bf37159568',NULL,'identity-provider-redirector','dab18c5a-b240-4256-b8a9-31247dda96ac','4efe3e4a-9c6c-4be6-9dec-15455a18d4e9',2,25,'\0',NULL,NULL),
('9cfeb19a-1acd-4cf6-a8bf-271de827bce1',NULL,'registration-user-creation','dab18c5a-b240-4256-b8a9-31247dda96ac','54e4dfb1-c8df-4e1b-8975-31f13cc503c9',0,20,'\0',NULL,NULL),
('9d2ef15f-1145-409b-9aec-b0995057845a',NULL,'idp-create-user-if-unique','dab18c5a-b240-4256-b8a9-31247dda96ac','cae6de0e-18bf-4c98-9d4c-3a424521196c',2,10,'\0',NULL,'8eb51564-feff-4326-9f3c-ff5f74738f0e'),
('a0411855-b5ee-4dce-830c-68e6ccf42044',NULL,'client-x509','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','912298d3-c338-4ec1-8118-558c739617dd',2,40,'\0',NULL,NULL),
('a1faedc3-0304-44a4-91c3-85ee7333f22b',NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','3e23735b-82fd-40c0-aa35-1b23adcafa70',2,20,'','5696c659-6c77-458d-95a9-fd2b2563ee06',NULL),
('a5fbb12b-c4e5-470f-b152-ea8f0be92361',NULL,'reset-credential-email','dab18c5a-b240-4256-b8a9-31247dda96ac','0d78c1a6-232b-44c0-ab89-02c34086e849',0,20,'\0',NULL,NULL),
('ab822bd8-617a-4c1a-9fcd-11a0b82ea74b',NULL,'auth-username-password-form','dab18c5a-b240-4256-b8a9-31247dda96ac','e1a7e6c0-6d27-49ef-a1a3-891ceb72661e',0,10,'\0',NULL,NULL),
('b5085bb6-4d66-45f1-9ae0-644707719558',NULL,'auth-otp-form','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','b576deeb-6294-440a-a391-1483bbd39989',0,20,'\0',NULL,NULL),
('bc4d3acc-55bf-4be6-9b01-052a2bf82641',NULL,'auth-spnego','dab18c5a-b240-4256-b8a9-31247dda96ac','4efe3e4a-9c6c-4be6-9dec-15455a18d4e9',3,20,'\0',NULL,NULL),
('c092c2cd-1217-437f-978a-39344a2ae07a',NULL,'client-secret-jwt','dab18c5a-b240-4256-b8a9-31247dda96ac','da0c5ab5-14a6-40b7-b100-de65281caa75',2,30,'\0',NULL,NULL),
('c391bc87-9d62-4342-b536-124e526fcb09',NULL,'auth-otp-form','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','0402faae-c0a7-422e-b6fa-463f49d2d0e1',0,20,'\0',NULL,NULL),
('c76cfef7-70f5-4d65-b313-e2645c6979d6',NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','4efe3e4a-9c6c-4be6-9dec-15455a18d4e9',2,30,'','e1a7e6c0-6d27-49ef-a1a3-891ceb72661e',NULL),
('cab002ae-5b2e-44e3-8a17-4cab16ca48a5',NULL,'direct-grant-validate-password','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','12a7f999-a43e-473a-a05e-98f4d8587703',0,20,'\0',NULL,NULL),
('d01ef3c6-b447-4f4d-a3a5-85bcdf61aa4f',NULL,'client-secret-jwt','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','912298d3-c338-4ec1-8118-558c739617dd',2,30,'\0',NULL,NULL),
('d646783e-0e7e-4f57-9cf1-2ddc04268e72',NULL,'client-jwt','dab18c5a-b240-4256-b8a9-31247dda96ac','da0c5ab5-14a6-40b7-b100-de65281caa75',2,20,'\0',NULL,NULL),
('d7fb36da-0636-42bf-82fc-f028f77ae4f4',NULL,'idp-email-verification','dab18c5a-b240-4256-b8a9-31247dda96ac','3e23735b-82fd-40c0-aa35-1b23adcafa70',2,10,'\0',NULL,NULL),
('d8a2b761-239d-4699-b70e-55e40d4bc9f4',NULL,'idp-review-profile','dab18c5a-b240-4256-b8a9-31247dda96ac','c0ead02b-de63-4b9b-86e9-93fb8e857853',0,10,'\0',NULL,'456f70f1-880b-4380-a61c-3e5c17cc4176'),
('da5e9d16-663c-4802-8a41-834f2e1ce2ca',NULL,'docker-http-basic-authenticator','dab18c5a-b240-4256-b8a9-31247dda96ac','fc0dd3c8-5b32-4d68-a1cb-cab3bc7930b1',0,10,'\0',NULL,NULL),
('dd07a7be-9b45-4cf7-a122-4834af8b9ced',NULL,'docker-http-basic-authenticator','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','f40853ac-903a-4beb-99fa-9a8758b6f614',0,10,'\0',NULL,NULL),
('deb3a8de-c301-428d-b2f4-0a57b80130fd',NULL,'reset-credentials-choose-user','dab18c5a-b240-4256-b8a9-31247dda96ac','0d78c1a6-232b-44c0-ab89-02c34086e849',0,10,'\0',NULL,NULL),
('e4b66966-1915-48e5-960a-80856f9f5582',NULL,'idp-confirm-link','dab18c5a-b240-4256-b8a9-31247dda96ac','b92334cb-ab49-46a3-af3a-bb9f8a893a06',0,10,'\0',NULL,NULL),
('e4d1b3e9-a4e7-4bdc-9193-07f140e40315',NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','0d78c1a6-232b-44c0-ab89-02c34086e849',1,40,'','cb45781e-e70a-4fe2-9f2f-05420897c633',NULL),
('e6e3529a-b8f9-4e05-8ebf-313980f7790c',NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','c0ead02b-de63-4b9b-86e9-93fb8e857853',0,20,'','cae6de0e-18bf-4c98-9d4c-3a424521196c',NULL),
('e844337d-55c0-4cf0-98a8-2899ac2daff4',NULL,'idp-review-profile','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','8283dc5d-6f9a-457a-be33-4004a49e013b',0,10,'\0',NULL,'3a2dcebe-28ff-4468-94fd-c0544a031392'),
('eba18ef5-d43e-451a-9af5-32ef760480a0',NULL,NULL,'4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','8a1fbbad-91cc-44f7-bde2-59013dd48ff7',2,20,'','c9c521a4-c291-408b-9305-30c4b4be4edb',NULL),
('eeb97508-cc54-4430-8a78-7286ccee0f7b',NULL,NULL,'4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','12a7f999-a43e-473a-a05e-98f4d8587703',1,30,'','fad0b67f-c9d3-4486-9422-ceb56ad7117d',NULL),
('efc3072a-604c-47c4-94dd-4cda07362729',NULL,'registration-page-form','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','f8db8a48-ae22-48de-920a-4d75fa7c93a4',0,10,'','6ca473b1-f977-42fd-b50e-91a5377a6998',NULL),
('efdfeca9-4f3f-43f1-a98c-3a1826abfb32',NULL,'registration-page-form','dab18c5a-b240-4256-b8a9-31247dda96ac','7525e48e-e268-48bb-ae16-26e791a8774d',0,10,'','54e4dfb1-c8df-4e1b-8975-31f13cc503c9',NULL),
('f2090090-8dd6-4680-acf7-922e670fa720',NULL,'http-basic-authenticator','dab18c5a-b240-4256-b8a9-31247dda96ac','329e52d1-ddba-4d6d-a6e0-23eb4418b262',0,10,'\0',NULL,NULL),
('f4960425-54a6-4f79-b960-ecfd587b60f0',NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','b92334cb-ab49-46a3-af3a-bb9f8a893a06',0,20,'','3e23735b-82fd-40c0-aa35-1b23adcafa70',NULL),
('f79ab9e6-03e1-4a1d-9bdf-7a343e2a3fa2',NULL,'identity-provider-redirector','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','2a0c99b8-9d40-44d4-8aa9-c051fc797660',2,25,'\0',NULL,NULL),
('fd671007-4a75-4617-a49b-ef98c2a550be',NULL,'conditional-user-configured','dab18c5a-b240-4256-b8a9-31247dda96ac','cb45781e-e70a-4fe2-9f2f-05420897c633',0,10,'\0',NULL,NULL);
/*!40000 ALTER TABLE `AUTHENTICATION_EXECUTION` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `AUTHENTICATION_FLOW`
--

DROP TABLE IF EXISTS `AUTHENTICATION_FLOW`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AUTHENTICATION_FLOW` (
  `ID` varchar(36) NOT NULL,
  `ALIAS` varchar(255) DEFAULT NULL,
  `DESCRIPTION` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `REALM_ID` varchar(36) DEFAULT NULL,
  `PROVIDER_ID` varchar(36) NOT NULL DEFAULT 'basic-flow',
  `TOP_LEVEL` bit(1) NOT NULL DEFAULT b'0',
  `BUILT_IN` bit(1) NOT NULL DEFAULT b'0',
  PRIMARY KEY (`ID`),
  KEY `IDX_AUTH_FLOW_REALM` (`REALM_ID`),
  CONSTRAINT `FK_AUTH_FLOW_REALM` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `AUTHENTICATION_FLOW`
--

LOCK TABLES `AUTHENTICATION_FLOW` WRITE;
/*!40000 ALTER TABLE `AUTHENTICATION_FLOW` DISABLE KEYS */;
INSERT INTO `AUTHENTICATION_FLOW` VALUES
('0402faae-c0a7-422e-b6fa-463f49d2d0e1','Browser - Conditional OTP','Flow to determine if the OTP is required for the authentication','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','\0',''),
('0d78c1a6-232b-44c0-ab89-02c34086e849','reset credentials','Reset credentials for a user if they forgot their password or something','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','',''),
('12a7f999-a43e-473a-a05e-98f4d8587703','direct grant','OpenID Connect Resource Owner Grant','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','',''),
('23687fce-aeb8-45c0-8357-54f24e6b9f4e','Account verification options','Method with which to verity the existing account','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','\0',''),
('2a0c99b8-9d40-44d4-8aa9-c051fc797660','browser','browser based authentication','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','',''),
('316d995f-e8bb-49d8-9bb6-e11a0ac074ea','saml ecp','SAML ECP Profile Authentication Flow','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','',''),
('329e52d1-ddba-4d6d-a6e0-23eb4418b262','saml ecp','SAML ECP Profile Authentication Flow','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','',''),
('3e23735b-82fd-40c0-aa35-1b23adcafa70','Account verification options','Method with which to verity the existing account','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','\0',''),
('4efe3e4a-9c6c-4be6-9dec-15455a18d4e9','browser','browser based authentication','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','',''),
('54e4dfb1-c8df-4e1b-8975-31f13cc503c9','registration form','registration form','dab18c5a-b240-4256-b8a9-31247dda96ac','form-flow','\0',''),
('5696c659-6c77-458d-95a9-fd2b2563ee06','Verify Existing Account by Re-authentication','Reauthentication of existing account','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','\0',''),
('5fc7960f-4854-424a-9fad-c43840b87c0c','First broker login - Conditional OTP','Flow to determine if the OTP is required for the authentication','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','\0',''),
('6ca473b1-f977-42fd-b50e-91a5377a6998','registration form','registration form','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','form-flow','\0',''),
('7525e48e-e268-48bb-ae16-26e791a8774d','registration','registration flow','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','',''),
('8283dc5d-6f9a-457a-be33-4004a49e013b','first broker login','Actions taken after first broker login with identity provider account, which is not yet linked to any Keycloak account','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','',''),
('8a1fbbad-91cc-44f7-bde2-59013dd48ff7','User creation or linking','Flow for the existing/non-existing user alternatives','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','\0',''),
('912298d3-c338-4ec1-8118-558c739617dd','clients','Base authentication for clients','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','client-flow','',''),
('9bc23c86-ef45-4257-b3fe-56fc2c7850a1','forms','Username, password, otp and other auth forms.','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','\0',''),
('a1cbf9b5-224d-4e1e-a6bf-d780ec5a49a2','reset credentials','Reset credentials for a user if they forgot their password or something','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','',''),
('b576deeb-6294-440a-a391-1483bbd39989','First broker login - Conditional OTP','Flow to determine if the OTP is required for the authentication','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','\0',''),
('b92334cb-ab49-46a3-af3a-bb9f8a893a06','Handle Existing Account','Handle what to do if there is existing account with same email/username like authenticated identity provider','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','\0',''),
('c0ead02b-de63-4b9b-86e9-93fb8e857853','first broker login','Actions taken after first broker login with identity provider account, which is not yet linked to any Keycloak account','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','',''),
('c2303c15-6ebd-4513-960f-2faf7a69681b','Verify Existing Account by Re-authentication','Reauthentication of existing account','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','\0',''),
('c961857a-9867-47ba-8f6c-7c3d52a303cc','Direct Grant - Conditional OTP','Flow to determine if the OTP is required for the authentication','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','\0',''),
('c9c521a4-c291-408b-9305-30c4b4be4edb','Handle Existing Account','Handle what to do if there is existing account with same email/username like authenticated identity provider','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','\0',''),
('cae6de0e-18bf-4c98-9d4c-3a424521196c','User creation or linking','Flow for the existing/non-existing user alternatives','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','\0',''),
('cb45781e-e70a-4fe2-9f2f-05420897c633','Reset - Conditional OTP','Flow to determine if the OTP should be reset or not. Set to REQUIRED to force.','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','\0',''),
('cccf5b19-8db8-4589-af41-02cfcd00fca8','Reset - Conditional OTP','Flow to determine if the OTP should be reset or not. Set to REQUIRED to force.','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','\0',''),
('d2055d66-a9b7-4e74-9a10-e7ecfd9e8c1b','direct grant','OpenID Connect Resource Owner Grant','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','',''),
('d4059983-21af-4295-b5f1-a3e5222f8399','Browser - Conditional OTP','Flow to determine if the OTP is required for the authentication','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','\0',''),
('da0c5ab5-14a6-40b7-b100-de65281caa75','clients','Base authentication for clients','dab18c5a-b240-4256-b8a9-31247dda96ac','client-flow','',''),
('e1a7e6c0-6d27-49ef-a1a3-891ceb72661e','forms','Username, password, otp and other auth forms.','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','\0',''),
('f40853ac-903a-4beb-99fa-9a8758b6f614','docker auth','Used by Docker clients to authenticate against the IDP','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','',''),
('f8db8a48-ae22-48de-920a-4d75fa7c93a4','registration','registration flow','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','',''),
('fad0b67f-c9d3-4486-9422-ceb56ad7117d','Direct Grant - Conditional OTP','Flow to determine if the OTP is required for the authentication','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','basic-flow','\0',''),
('fc0dd3c8-5b32-4d68-a1cb-cab3bc7930b1','docker auth','Used by Docker clients to authenticate against the IDP','dab18c5a-b240-4256-b8a9-31247dda96ac','basic-flow','','');
/*!40000 ALTER TABLE `AUTHENTICATION_FLOW` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `AUTHENTICATOR_CONFIG`
--

DROP TABLE IF EXISTS `AUTHENTICATOR_CONFIG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AUTHENTICATOR_CONFIG` (
  `ID` varchar(36) NOT NULL,
  `ALIAS` varchar(255) DEFAULT NULL,
  `REALM_ID` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_AUTH_CONFIG_REALM` (`REALM_ID`),
  CONSTRAINT `FK_AUTH_REALM` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `AUTHENTICATOR_CONFIG`
--

LOCK TABLES `AUTHENTICATOR_CONFIG` WRITE;
/*!40000 ALTER TABLE `AUTHENTICATOR_CONFIG` DISABLE KEYS */;
INSERT INTO `AUTHENTICATOR_CONFIG` VALUES
('3a2dcebe-28ff-4468-94fd-c0544a031392','review profile config','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86'),
('456f70f1-880b-4380-a61c-3e5c17cc4176','review profile config','dab18c5a-b240-4256-b8a9-31247dda96ac'),
('8eb51564-feff-4326-9f3c-ff5f74738f0e','create unique user config','dab18c5a-b240-4256-b8a9-31247dda96ac'),
('eac0cb1e-3175-4eaa-afdf-02c5d66a1108','create unique user config','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86');
/*!40000 ALTER TABLE `AUTHENTICATOR_CONFIG` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `AUTHENTICATOR_CONFIG_ENTRY`
--

DROP TABLE IF EXISTS `AUTHENTICATOR_CONFIG_ENTRY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AUTHENTICATOR_CONFIG_ENTRY` (
  `AUTHENTICATOR_ID` varchar(36) NOT NULL,
  `VALUE` longtext DEFAULT NULL,
  `NAME` varchar(255) NOT NULL,
  PRIMARY KEY (`AUTHENTICATOR_ID`,`NAME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `AUTHENTICATOR_CONFIG_ENTRY`
--

LOCK TABLES `AUTHENTICATOR_CONFIG_ENTRY` WRITE;
/*!40000 ALTER TABLE `AUTHENTICATOR_CONFIG_ENTRY` DISABLE KEYS */;
INSERT INTO `AUTHENTICATOR_CONFIG_ENTRY` VALUES
('3a2dcebe-28ff-4468-94fd-c0544a031392','missing','update.profile.on.first.login'),
('456f70f1-880b-4380-a61c-3e5c17cc4176','missing','update.profile.on.first.login'),
('8eb51564-feff-4326-9f3c-ff5f74738f0e','false','require.password.update.after.registration'),
('eac0cb1e-3175-4eaa-afdf-02c5d66a1108','false','require.password.update.after.registration');
/*!40000 ALTER TABLE `AUTHENTICATOR_CONFIG_ENTRY` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `BROKER_LINK`
--

DROP TABLE IF EXISTS `BROKER_LINK`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `BROKER_LINK` (
  `IDENTITY_PROVIDER` varchar(255) NOT NULL,
  `STORAGE_PROVIDER_ID` varchar(255) DEFAULT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  `BROKER_USER_ID` varchar(255) DEFAULT NULL,
  `BROKER_USERNAME` varchar(255) DEFAULT NULL,
  `TOKEN` text DEFAULT NULL,
  `USER_ID` varchar(255) NOT NULL,
  PRIMARY KEY (`IDENTITY_PROVIDER`,`USER_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `BROKER_LINK`
--

LOCK TABLES `BROKER_LINK` WRITE;
/*!40000 ALTER TABLE `BROKER_LINK` DISABLE KEYS */;
/*!40000 ALTER TABLE `BROKER_LINK` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT`
--

DROP TABLE IF EXISTS `CLIENT`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT` (
  `ID` varchar(36) NOT NULL,
  `ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `FULL_SCOPE_ALLOWED` bit(1) NOT NULL DEFAULT b'0',
  `CLIENT_ID` varchar(255) DEFAULT NULL,
  `NOT_BEFORE` int(11) DEFAULT NULL,
  `PUBLIC_CLIENT` bit(1) NOT NULL DEFAULT b'0',
  `SECRET` varchar(255) DEFAULT NULL,
  `BASE_URL` varchar(255) DEFAULT NULL,
  `BEARER_ONLY` bit(1) NOT NULL DEFAULT b'0',
  `MANAGEMENT_URL` varchar(255) DEFAULT NULL,
  `SURROGATE_AUTH_REQUIRED` bit(1) NOT NULL DEFAULT b'0',
  `REALM_ID` varchar(36) DEFAULT NULL,
  `PROTOCOL` varchar(255) DEFAULT NULL,
  `NODE_REREG_TIMEOUT` int(11) DEFAULT 0,
  `FRONTCHANNEL_LOGOUT` bit(1) NOT NULL DEFAULT b'0',
  `CONSENT_REQUIRED` bit(1) NOT NULL DEFAULT b'0',
  `NAME` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `SERVICE_ACCOUNTS_ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `CLIENT_AUTHENTICATOR_TYPE` varchar(255) DEFAULT NULL,
  `ROOT_URL` varchar(255) DEFAULT NULL,
  `DESCRIPTION` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `REGISTRATION_TOKEN` varchar(255) DEFAULT NULL,
  `STANDARD_FLOW_ENABLED` bit(1) NOT NULL DEFAULT b'1',
  `IMPLICIT_FLOW_ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `DIRECT_ACCESS_GRANTS_ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `ALWAYS_DISPLAY_IN_CONSOLE` bit(1) NOT NULL DEFAULT b'0',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UK_B71CJLBENV945RB6GCON438AT` (`REALM_ID`,`CLIENT_ID`),
  KEY `IDX_CLIENT_ID` (`CLIENT_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT`
--

LOCK TABLES `CLIENT` WRITE;
/*!40000 ALTER TABLE `CLIENT` DISABLE KEYS */;
INSERT INTO `CLIENT` VALUES
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','','\0','security-admin-console',0,'',NULL,'/admin/contrabass/console/','\0',NULL,'\0','dab18c5a-b240-4256-b8a9-31247dda96ac','openid-connect',0,'\0','\0','${client_security-admin-console}','\0','client-secret','${authAdminUrl}',NULL,NULL,'','\0','\0','\0'),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','','\0','account',0,'',NULL,'/realms/contrabass/account/','\0',NULL,'\0','dab18c5a-b240-4256-b8a9-31247dda96ac','openid-connect',0,'\0','\0','${client_account}','\0','client-secret','${authBaseUrl}',NULL,NULL,'','\0','\0','\0'),
('318c3a27-e2db-4c7c-90c6-d08edb13e055','','\0','admin-cli',0,'',NULL,NULL,'\0',NULL,'\0','dab18c5a-b240-4256-b8a9-31247dda96ac','openid-connect',0,'\0','\0','${client_admin-cli}','\0','client-secret',NULL,NULL,NULL,'\0','\0','','\0'),
('5783ae22-22b9-411d-a1c5-358b4e5b08a4','','\0','broker',0,'\0',NULL,NULL,'',NULL,'\0','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','openid-connect',0,'\0','\0','${client_broker}','\0','client-secret',NULL,NULL,NULL,'','\0','\0','\0'),
('69b3d96b-db94-4825-b7be-95919a24d55a','','\0','security-admin-console',0,'',NULL,'/admin/master/console/','\0',NULL,'\0','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','openid-connect',0,'\0','\0','${client_security-admin-console}','\0','client-secret','${authAdminUrl}',NULL,NULL,'','\0','\0','\0'),
('734008f7-c43e-46e5-8ca8-1cefd1177608','','\0','admin-cli',0,'',NULL,NULL,'\0',NULL,'\0','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','openid-connect',0,'\0','\0','${client_admin-cli}','\0','client-secret',NULL,NULL,NULL,'\0','\0','','\0'),
('99663a99-9477-4699-a933-e91d41961578','','\0','account-console',0,'',NULL,'/realms/contrabass/account/','\0',NULL,'\0','dab18c5a-b240-4256-b8a9-31247dda96ac','openid-connect',0,'\0','\0','${client_account-console}','\0','client-secret','${authBaseUrl}',NULL,NULL,'','\0','\0','\0'),
('9db49952-1afc-4232-98ff-5adb2d5b8e72','','\0','contrabass-realm',0,'\0',NULL,NULL,'',NULL,'\0','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',NULL,0,'\0','\0','contrabass Realm','\0','client-secret',NULL,NULL,NULL,'','\0','\0','\0'),
('a6f6cb61-4f2a-4932-a629-b58e25de88ca','','\0','broker',0,'\0',NULL,NULL,'',NULL,'\0','dab18c5a-b240-4256-b8a9-31247dda96ac','openid-connect',0,'\0','\0','${client_broker}','\0','client-secret',NULL,NULL,NULL,'','\0','\0','\0'),
('a866e702-403e-4aab-905d-18a4ef119cfe','','\0','realm-management',0,'\0','E5RjsbWXvCpIYuhgvItt15eMOs8gqXjK',NULL,'\0',NULL,'\0','dab18c5a-b240-4256-b8a9-31247dda96ac','openid-connect',0,'\0','\0','${client_realm-management}','','client-secret',NULL,NULL,NULL,'','\0','\0','\0'),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','','\0','account-console',0,'',NULL,'/realms/master/account/','\0',NULL,'\0','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','openid-connect',0,'\0','\0','${client_account-console}','\0','client-secret','${authBaseUrl}',NULL,NULL,'','\0','\0','\0'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','','','contrabass-client',0,'\0','MCNiUHkTbeMdxae6mjaGyHY3FMjakx8g','https://contrabass.os:9443','\0','','\0','dab18c5a-b240-4256-b8a9-31247dda96ac','openid-connect',-1,'','\0','마에스트로 Admin 포탈','','client-secret','https://contrabass.os:9443','마에스트로 Admin 포탈',NULL,'','\0','\0','\0'),
('cf784c13-493e-4d43-86ee-8b9c81845b12','','\0','account',0,'',NULL,'/realms/master/account/','\0',NULL,'\0','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','openid-connect',0,'\0','\0','${client_account}','\0','client-secret','${authBaseUrl}',NULL,NULL,'','\0','\0','\0'),
('dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','\0','master-realm',0,'\0',NULL,NULL,'',NULL,'\0','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',NULL,0,'\0','\0','master Realm','\0','client-secret',NULL,NULL,NULL,'','\0','\0','\0');
/*!40000 ALTER TABLE `CLIENT` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_ATTRIBUTES`
--

DROP TABLE IF EXISTS `CLIENT_ATTRIBUTES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_ATTRIBUTES` (
  `CLIENT_ID` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `VALUE` longtext CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  PRIMARY KEY (`CLIENT_ID`,`NAME`),
  KEY `IDX_CLIENT_ATT_BY_NAME_VALUE` (`NAME`),
  CONSTRAINT `FK3C47C64BEACCA966` FOREIGN KEY (`CLIENT_ID`) REFERENCES `CLIENT` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_ATTRIBUTES`
--

LOCK TABLES `CLIENT_ATTRIBUTES` WRITE;
/*!40000 ALTER TABLE `CLIENT_ATTRIBUTES` DISABLE KEYS */;
INSERT INTO `CLIENT_ATTRIBUTES` VALUES
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','pkce.code.challenge.method','S256'),
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','post.logout.redirect.uris','+'),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','post.logout.redirect.uris','+'),
('318c3a27-e2db-4c7c-90c6-d08edb13e055','post.logout.redirect.uris','+'),
('69b3d96b-db94-4825-b7be-95919a24d55a','pkce.code.challenge.method','S256'),
('69b3d96b-db94-4825-b7be-95919a24d55a','post.logout.redirect.uris','+'),
('99663a99-9477-4699-a933-e91d41961578','pkce.code.challenge.method','S256'),
('99663a99-9477-4699-a933-e91d41961578','post.logout.redirect.uris','+'),
('a6f6cb61-4f2a-4932-a629-b58e25de88ca','post.logout.redirect.uris','+'),
('a866e702-403e-4aab-905d-18a4ef119cfe','client.secret.creation.time','1743396835'),
('a866e702-403e-4aab-905d-18a4ef119cfe','post.logout.redirect.uris','+'),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','pkce.code.challenge.method','S256'),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','post.logout.redirect.uris','+'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','access.token.lifespan','86400'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','acr.loa.map','{}'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','backchannel.logout.revoke.offline.tokens','false'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','backchannel.logout.session.required','false'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','client.secret.creation.time','1706539216'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','client_credentials.use_refresh_token','false'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','display.on.consent.screen','false'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','login_theme','okestro-theme-admin+display-HTML'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','oauth2.device.authorization.grant.enabled','false'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','oidc.ciba.grant.enabled','false'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','post.logout.redirect.uris','https://contrabass.os:9443/*'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','require.pushed.authorization.requests','false'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','tls-client-certificate-bound-access-tokens','false'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','token.response.type.bearer.lower-case','false'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','use.jwks.url','false'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','use.refresh.tokens','false'),
('cf784c13-493e-4d43-86ee-8b9c81845b12','post.logout.redirect.uris','+');
/*!40000 ALTER TABLE `CLIENT_ATTRIBUTES` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_AUTH_FLOW_BINDINGS`
--

DROP TABLE IF EXISTS `CLIENT_AUTH_FLOW_BINDINGS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_AUTH_FLOW_BINDINGS` (
  `CLIENT_ID` varchar(36) NOT NULL,
  `FLOW_ID` varchar(36) DEFAULT NULL,
  `BINDING_NAME` varchar(255) NOT NULL,
  PRIMARY KEY (`CLIENT_ID`,`BINDING_NAME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_AUTH_FLOW_BINDINGS`
--

LOCK TABLES `CLIENT_AUTH_FLOW_BINDINGS` WRITE;
/*!40000 ALTER TABLE `CLIENT_AUTH_FLOW_BINDINGS` DISABLE KEYS */;
INSERT INTO `CLIENT_AUTH_FLOW_BINDINGS` VALUES
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','4efe3e4a-9c6c-4be6-9dec-15455a18d4e9','browser'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','d2055d66-a9b7-4e74-9a10-e7ecfd9e8c1b','direct_grant');
/*!40000 ALTER TABLE `CLIENT_AUTH_FLOW_BINDINGS` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_INITIAL_ACCESS`
--

DROP TABLE IF EXISTS `CLIENT_INITIAL_ACCESS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_INITIAL_ACCESS` (
  `ID` varchar(36) NOT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  `TIMESTAMP` int(11) DEFAULT NULL,
  `EXPIRATION` int(11) DEFAULT NULL,
  `COUNT` int(11) DEFAULT NULL,
  `REMAINING_COUNT` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_CLIENT_INIT_ACC_REALM` (`REALM_ID`),
  CONSTRAINT `FK_CLIENT_INIT_ACC_REALM` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_INITIAL_ACCESS`
--

LOCK TABLES `CLIENT_INITIAL_ACCESS` WRITE;
/*!40000 ALTER TABLE `CLIENT_INITIAL_ACCESS` DISABLE KEYS */;
/*!40000 ALTER TABLE `CLIENT_INITIAL_ACCESS` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_NODE_REGISTRATIONS`
--

DROP TABLE IF EXISTS `CLIENT_NODE_REGISTRATIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_NODE_REGISTRATIONS` (
  `CLIENT_ID` varchar(36) NOT NULL,
  `VALUE` int(11) DEFAULT NULL,
  `NAME` varchar(255) NOT NULL,
  PRIMARY KEY (`CLIENT_ID`,`NAME`),
  CONSTRAINT `FK4129723BA992F594` FOREIGN KEY (`CLIENT_ID`) REFERENCES `CLIENT` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_NODE_REGISTRATIONS`
--

LOCK TABLES `CLIENT_NODE_REGISTRATIONS` WRITE;
/*!40000 ALTER TABLE `CLIENT_NODE_REGISTRATIONS` DISABLE KEYS */;
/*!40000 ALTER TABLE `CLIENT_NODE_REGISTRATIONS` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_SCOPE`
--

DROP TABLE IF EXISTS `CLIENT_SCOPE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_SCOPE` (
  `ID` varchar(36) NOT NULL,
  `NAME` varchar(255) DEFAULT NULL,
  `REALM_ID` varchar(36) DEFAULT NULL,
  `DESCRIPTION` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `PROTOCOL` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UK_CLI_SCOPE` (`REALM_ID`,`NAME`),
  KEY `IDX_REALM_CLSCOPE` (`REALM_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_SCOPE`
--

LOCK TABLES `CLIENT_SCOPE` WRITE;
/*!40000 ALTER TABLE `CLIENT_SCOPE` DISABLE KEYS */;
INSERT INTO `CLIENT_SCOPE` VALUES
('1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','offline_access','dab18c5a-b240-4256-b8a9-31247dda96ac','OpenID Connect built-in scope: offline_access','openid-connect'),
('32ad3d0c-d877-4811-bcfd-474b40ad1e8d','email','dab18c5a-b240-4256-b8a9-31247dda96ac','OpenID Connect built-in scope: email','openid-connect'),
('36f24f6c-f32a-4537-977b-dff0b0de9470','role_list','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','SAML role list','saml'),
('4277aaef-8983-44c7-81c6-d3c3485aa3fa','microprofile-jwt','dab18c5a-b240-4256-b8a9-31247dda96ac','Microprofile - JWT built-in scope','openid-connect'),
('43bd3461-2d5e-412c-96cd-125e4e2785b5','offline_access','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','OpenID Connect built-in scope: offline_access','openid-connect'),
('564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d','email','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','OpenID Connect built-in scope: email','openid-connect'),
('5e701f0b-2581-4458-a171-fdf2aa34d1c9','acr','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','OpenID Connect scope for add acr (authentication context class reference) to the token','openid-connect'),
('608e02cb-3f63-4e89-9258-fbd1c7c6d8f0','roles','dab18c5a-b240-4256-b8a9-31247dda96ac','OpenID Connect scope for add user roles to the access token','openid-connect'),
('7538c9cb-f57d-4358-a073-1eb9bcbe0f29','microprofile-jwt','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','Microprofile - JWT built-in scope','openid-connect'),
('7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706','web-origins','dab18c5a-b240-4256-b8a9-31247dda96ac','OpenID Connect scope for add allowed web origins to the access token','openid-connect'),
('92fb03e0-4c6d-4b25-ac33-54ace6e61139','roles','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','OpenID Connect scope for add user roles to the access token','openid-connect'),
('980ab3c2-627a-4b0f-82fe-3e9216cdda7f','profile','dab18c5a-b240-4256-b8a9-31247dda96ac','OpenID Connect built-in scope: profile','openid-connect'),
('a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','phone','dab18c5a-b240-4256-b8a9-31247dda96ac','OpenID Connect built-in scope: phone','openid-connect'),
('b9130729-e811-4118-9c3c-2fe95a93bd5a','profile','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','OpenID Connect built-in scope: profile','openid-connect'),
('c47be204-f074-4670-8bd3-fd526ef41655','phone','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','OpenID Connect built-in scope: phone','openid-connect'),
('cecca841-4cd1-4f09-8724-fa20c73281b8','address','dab18c5a-b240-4256-b8a9-31247dda96ac','OpenID Connect built-in scope: address','openid-connect'),
('e3c658f5-9390-4b8d-a333-062a54a65ba5','web-origins','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','OpenID Connect scope for add allowed web origins to the access token','openid-connect'),
('e3f1e796-a25e-4e58-a07d-5362a6d0139c','role_list','dab18c5a-b240-4256-b8a9-31247dda96ac','SAML role list','saml'),
('e5c89cef-3d47-4a27-882c-9cd6cb52d7ff','address','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','OpenID Connect built-in scope: address','openid-connect'),
('f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9','acr','dab18c5a-b240-4256-b8a9-31247dda96ac','OpenID Connect scope for add acr (authentication context class reference) to the token','openid-connect');
/*!40000 ALTER TABLE `CLIENT_SCOPE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_SCOPE_ATTRIBUTES`
--

DROP TABLE IF EXISTS `CLIENT_SCOPE_ATTRIBUTES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_SCOPE_ATTRIBUTES` (
  `SCOPE_ID` varchar(36) NOT NULL,
  `VALUE` text DEFAULT NULL,
  `NAME` varchar(255) NOT NULL,
  PRIMARY KEY (`SCOPE_ID`,`NAME`),
  KEY `IDX_CLSCOPE_ATTRS` (`SCOPE_ID`),
  CONSTRAINT `FK_CL_SCOPE_ATTR_SCOPE` FOREIGN KEY (`SCOPE_ID`) REFERENCES `CLIENT_SCOPE` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_SCOPE_ATTRIBUTES`
--

LOCK TABLES `CLIENT_SCOPE_ATTRIBUTES` WRITE;
/*!40000 ALTER TABLE `CLIENT_SCOPE_ATTRIBUTES` DISABLE KEYS */;
INSERT INTO `CLIENT_SCOPE_ATTRIBUTES` VALUES
('1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','${offlineAccessScopeConsentText}','consent.screen.text'),
('1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','true','display.on.consent.screen'),
('32ad3d0c-d877-4811-bcfd-474b40ad1e8d','${emailScopeConsentText}','consent.screen.text'),
('32ad3d0c-d877-4811-bcfd-474b40ad1e8d','true','display.on.consent.screen'),
('32ad3d0c-d877-4811-bcfd-474b40ad1e8d','true','include.in.token.scope'),
('36f24f6c-f32a-4537-977b-dff0b0de9470','${samlRoleListScopeConsentText}','consent.screen.text'),
('36f24f6c-f32a-4537-977b-dff0b0de9470','true','display.on.consent.screen'),
('4277aaef-8983-44c7-81c6-d3c3485aa3fa','false','display.on.consent.screen'),
('4277aaef-8983-44c7-81c6-d3c3485aa3fa','true','include.in.token.scope'),
('43bd3461-2d5e-412c-96cd-125e4e2785b5','${offlineAccessScopeConsentText}','consent.screen.text'),
('43bd3461-2d5e-412c-96cd-125e4e2785b5','true','display.on.consent.screen'),
('564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d','${emailScopeConsentText}','consent.screen.text'),
('564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d','true','display.on.consent.screen'),
('564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d','true','include.in.token.scope'),
('5e701f0b-2581-4458-a171-fdf2aa34d1c9','false','display.on.consent.screen'),
('5e701f0b-2581-4458-a171-fdf2aa34d1c9','false','include.in.token.scope'),
('608e02cb-3f63-4e89-9258-fbd1c7c6d8f0','${rolesScopeConsentText}','consent.screen.text'),
('608e02cb-3f63-4e89-9258-fbd1c7c6d8f0','true','display.on.consent.screen'),
('608e02cb-3f63-4e89-9258-fbd1c7c6d8f0','false','include.in.token.scope'),
('7538c9cb-f57d-4358-a073-1eb9bcbe0f29','false','display.on.consent.screen'),
('7538c9cb-f57d-4358-a073-1eb9bcbe0f29','true','include.in.token.scope'),
('7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706','','consent.screen.text'),
('7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706','false','display.on.consent.screen'),
('7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706','false','include.in.token.scope'),
('92fb03e0-4c6d-4b25-ac33-54ace6e61139','${rolesScopeConsentText}','consent.screen.text'),
('92fb03e0-4c6d-4b25-ac33-54ace6e61139','true','display.on.consent.screen'),
('92fb03e0-4c6d-4b25-ac33-54ace6e61139','false','include.in.token.scope'),
('980ab3c2-627a-4b0f-82fe-3e9216cdda7f','${profileScopeConsentText}','consent.screen.text'),
('980ab3c2-627a-4b0f-82fe-3e9216cdda7f','true','display.on.consent.screen'),
('980ab3c2-627a-4b0f-82fe-3e9216cdda7f','true','include.in.token.scope'),
('a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','${phoneScopeConsentText}','consent.screen.text'),
('a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','true','display.on.consent.screen'),
('a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','true','include.in.token.scope'),
('b9130729-e811-4118-9c3c-2fe95a93bd5a','${profileScopeConsentText}','consent.screen.text'),
('b9130729-e811-4118-9c3c-2fe95a93bd5a','true','display.on.consent.screen'),
('b9130729-e811-4118-9c3c-2fe95a93bd5a','true','include.in.token.scope'),
('c47be204-f074-4670-8bd3-fd526ef41655','${phoneScopeConsentText}','consent.screen.text'),
('c47be204-f074-4670-8bd3-fd526ef41655','true','display.on.consent.screen'),
('c47be204-f074-4670-8bd3-fd526ef41655','true','include.in.token.scope'),
('cecca841-4cd1-4f09-8724-fa20c73281b8','${addressScopeConsentText}','consent.screen.text'),
('cecca841-4cd1-4f09-8724-fa20c73281b8','true','display.on.consent.screen'),
('cecca841-4cd1-4f09-8724-fa20c73281b8','true','include.in.token.scope'),
('e3c658f5-9390-4b8d-a333-062a54a65ba5','','consent.screen.text'),
('e3c658f5-9390-4b8d-a333-062a54a65ba5','false','display.on.consent.screen'),
('e3c658f5-9390-4b8d-a333-062a54a65ba5','false','include.in.token.scope'),
('e3f1e796-a25e-4e58-a07d-5362a6d0139c','${samlRoleListScopeConsentText}','consent.screen.text'),
('e3f1e796-a25e-4e58-a07d-5362a6d0139c','true','display.on.consent.screen'),
('e5c89cef-3d47-4a27-882c-9cd6cb52d7ff','${addressScopeConsentText}','consent.screen.text'),
('e5c89cef-3d47-4a27-882c-9cd6cb52d7ff','true','display.on.consent.screen'),
('e5c89cef-3d47-4a27-882c-9cd6cb52d7ff','true','include.in.token.scope'),
('f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9','false','display.on.consent.screen'),
('f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9','false','include.in.token.scope');
/*!40000 ALTER TABLE `CLIENT_SCOPE_ATTRIBUTES` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_SCOPE_CLIENT`
--

DROP TABLE IF EXISTS `CLIENT_SCOPE_CLIENT`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_SCOPE_CLIENT` (
  `CLIENT_ID` varchar(255) NOT NULL,
  `SCOPE_ID` varchar(255) NOT NULL,
  `DEFAULT_SCOPE` bit(1) NOT NULL DEFAULT b'0',
  PRIMARY KEY (`CLIENT_ID`,`SCOPE_ID`),
  KEY `IDX_CLSCOPE_CL` (`CLIENT_ID`),
  KEY `IDX_CL_CLSCOPE` (`SCOPE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_SCOPE_CLIENT`
--

LOCK TABLES `CLIENT_SCOPE_CLIENT` WRITE;
/*!40000 ALTER TABLE `CLIENT_SCOPE_CLIENT` DISABLE KEYS */;
INSERT INTO `CLIENT_SCOPE_CLIENT` VALUES
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','\0'),
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','32ad3d0c-d877-4811-bcfd-474b40ad1e8d',''),
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','4277aaef-8983-44c7-81c6-d3c3485aa3fa','\0'),
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','608e02cb-3f63-4e89-9258-fbd1c7c6d8f0',''),
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706',''),
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','980ab3c2-627a-4b0f-82fe-3e9216cdda7f',''),
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','\0'),
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','cecca841-4cd1-4f09-8724-fa20c73281b8','\0'),
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9',''),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','\0'),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','32ad3d0c-d877-4811-bcfd-474b40ad1e8d',''),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','4277aaef-8983-44c7-81c6-d3c3485aa3fa','\0'),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','608e02cb-3f63-4e89-9258-fbd1c7c6d8f0',''),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706',''),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','980ab3c2-627a-4b0f-82fe-3e9216cdda7f',''),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','\0'),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','cecca841-4cd1-4f09-8724-fa20c73281b8','\0'),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9',''),
('318c3a27-e2db-4c7c-90c6-d08edb13e055','1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','\0'),
('318c3a27-e2db-4c7c-90c6-d08edb13e055','32ad3d0c-d877-4811-bcfd-474b40ad1e8d',''),
('318c3a27-e2db-4c7c-90c6-d08edb13e055','4277aaef-8983-44c7-81c6-d3c3485aa3fa','\0'),
('318c3a27-e2db-4c7c-90c6-d08edb13e055','608e02cb-3f63-4e89-9258-fbd1c7c6d8f0',''),
('318c3a27-e2db-4c7c-90c6-d08edb13e055','7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706',''),
('318c3a27-e2db-4c7c-90c6-d08edb13e055','980ab3c2-627a-4b0f-82fe-3e9216cdda7f',''),
('318c3a27-e2db-4c7c-90c6-d08edb13e055','a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','\0'),
('318c3a27-e2db-4c7c-90c6-d08edb13e055','cecca841-4cd1-4f09-8724-fa20c73281b8','\0'),
('318c3a27-e2db-4c7c-90c6-d08edb13e055','f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9',''),
('5783ae22-22b9-411d-a1c5-358b4e5b08a4','43bd3461-2d5e-412c-96cd-125e4e2785b5','\0'),
('5783ae22-22b9-411d-a1c5-358b4e5b08a4','564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d',''),
('5783ae22-22b9-411d-a1c5-358b4e5b08a4','5e701f0b-2581-4458-a171-fdf2aa34d1c9',''),
('5783ae22-22b9-411d-a1c5-358b4e5b08a4','7538c9cb-f57d-4358-a073-1eb9bcbe0f29','\0'),
('5783ae22-22b9-411d-a1c5-358b4e5b08a4','92fb03e0-4c6d-4b25-ac33-54ace6e61139',''),
('5783ae22-22b9-411d-a1c5-358b4e5b08a4','b9130729-e811-4118-9c3c-2fe95a93bd5a',''),
('5783ae22-22b9-411d-a1c5-358b4e5b08a4','c47be204-f074-4670-8bd3-fd526ef41655','\0'),
('5783ae22-22b9-411d-a1c5-358b4e5b08a4','e3c658f5-9390-4b8d-a333-062a54a65ba5',''),
('5783ae22-22b9-411d-a1c5-358b4e5b08a4','e5c89cef-3d47-4a27-882c-9cd6cb52d7ff','\0'),
('69b3d96b-db94-4825-b7be-95919a24d55a','43bd3461-2d5e-412c-96cd-125e4e2785b5','\0'),
('69b3d96b-db94-4825-b7be-95919a24d55a','564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d',''),
('69b3d96b-db94-4825-b7be-95919a24d55a','5e701f0b-2581-4458-a171-fdf2aa34d1c9',''),
('69b3d96b-db94-4825-b7be-95919a24d55a','7538c9cb-f57d-4358-a073-1eb9bcbe0f29','\0'),
('69b3d96b-db94-4825-b7be-95919a24d55a','92fb03e0-4c6d-4b25-ac33-54ace6e61139',''),
('69b3d96b-db94-4825-b7be-95919a24d55a','b9130729-e811-4118-9c3c-2fe95a93bd5a',''),
('69b3d96b-db94-4825-b7be-95919a24d55a','c47be204-f074-4670-8bd3-fd526ef41655','\0'),
('69b3d96b-db94-4825-b7be-95919a24d55a','e3c658f5-9390-4b8d-a333-062a54a65ba5',''),
('69b3d96b-db94-4825-b7be-95919a24d55a','e5c89cef-3d47-4a27-882c-9cd6cb52d7ff','\0'),
('734008f7-c43e-46e5-8ca8-1cefd1177608','43bd3461-2d5e-412c-96cd-125e4e2785b5','\0'),
('734008f7-c43e-46e5-8ca8-1cefd1177608','564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d',''),
('734008f7-c43e-46e5-8ca8-1cefd1177608','5e701f0b-2581-4458-a171-fdf2aa34d1c9',''),
('734008f7-c43e-46e5-8ca8-1cefd1177608','7538c9cb-f57d-4358-a073-1eb9bcbe0f29','\0'),
('734008f7-c43e-46e5-8ca8-1cefd1177608','92fb03e0-4c6d-4b25-ac33-54ace6e61139',''),
('734008f7-c43e-46e5-8ca8-1cefd1177608','b9130729-e811-4118-9c3c-2fe95a93bd5a',''),
('734008f7-c43e-46e5-8ca8-1cefd1177608','c47be204-f074-4670-8bd3-fd526ef41655','\0'),
('734008f7-c43e-46e5-8ca8-1cefd1177608','e3c658f5-9390-4b8d-a333-062a54a65ba5',''),
('734008f7-c43e-46e5-8ca8-1cefd1177608','e5c89cef-3d47-4a27-882c-9cd6cb52d7ff','\0'),
('99663a99-9477-4699-a933-e91d41961578','1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','\0'),
('99663a99-9477-4699-a933-e91d41961578','32ad3d0c-d877-4811-bcfd-474b40ad1e8d',''),
('99663a99-9477-4699-a933-e91d41961578','4277aaef-8983-44c7-81c6-d3c3485aa3fa','\0'),
('99663a99-9477-4699-a933-e91d41961578','608e02cb-3f63-4e89-9258-fbd1c7c6d8f0',''),
('99663a99-9477-4699-a933-e91d41961578','7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706',''),
('99663a99-9477-4699-a933-e91d41961578','980ab3c2-627a-4b0f-82fe-3e9216cdda7f',''),
('99663a99-9477-4699-a933-e91d41961578','a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','\0'),
('99663a99-9477-4699-a933-e91d41961578','cecca841-4cd1-4f09-8724-fa20c73281b8','\0'),
('99663a99-9477-4699-a933-e91d41961578','f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9',''),
('a6f6cb61-4f2a-4932-a629-b58e25de88ca','1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','\0'),
('a6f6cb61-4f2a-4932-a629-b58e25de88ca','32ad3d0c-d877-4811-bcfd-474b40ad1e8d',''),
('a6f6cb61-4f2a-4932-a629-b58e25de88ca','4277aaef-8983-44c7-81c6-d3c3485aa3fa','\0'),
('a6f6cb61-4f2a-4932-a629-b58e25de88ca','608e02cb-3f63-4e89-9258-fbd1c7c6d8f0',''),
('a6f6cb61-4f2a-4932-a629-b58e25de88ca','7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706',''),
('a6f6cb61-4f2a-4932-a629-b58e25de88ca','980ab3c2-627a-4b0f-82fe-3e9216cdda7f',''),
('a6f6cb61-4f2a-4932-a629-b58e25de88ca','a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','\0'),
('a6f6cb61-4f2a-4932-a629-b58e25de88ca','cecca841-4cd1-4f09-8724-fa20c73281b8','\0'),
('a6f6cb61-4f2a-4932-a629-b58e25de88ca','f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9',''),
('a866e702-403e-4aab-905d-18a4ef119cfe','1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','\0'),
('a866e702-403e-4aab-905d-18a4ef119cfe','32ad3d0c-d877-4811-bcfd-474b40ad1e8d',''),
('a866e702-403e-4aab-905d-18a4ef119cfe','4277aaef-8983-44c7-81c6-d3c3485aa3fa','\0'),
('a866e702-403e-4aab-905d-18a4ef119cfe','608e02cb-3f63-4e89-9258-fbd1c7c6d8f0',''),
('a866e702-403e-4aab-905d-18a4ef119cfe','7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706',''),
('a866e702-403e-4aab-905d-18a4ef119cfe','980ab3c2-627a-4b0f-82fe-3e9216cdda7f',''),
('a866e702-403e-4aab-905d-18a4ef119cfe','a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','\0'),
('a866e702-403e-4aab-905d-18a4ef119cfe','cecca841-4cd1-4f09-8724-fa20c73281b8','\0'),
('a866e702-403e-4aab-905d-18a4ef119cfe','f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9',''),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','43bd3461-2d5e-412c-96cd-125e4e2785b5','\0'),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d',''),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','5e701f0b-2581-4458-a171-fdf2aa34d1c9',''),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','7538c9cb-f57d-4358-a073-1eb9bcbe0f29','\0'),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','92fb03e0-4c6d-4b25-ac33-54ace6e61139',''),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','b9130729-e811-4118-9c3c-2fe95a93bd5a',''),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','c47be204-f074-4670-8bd3-fd526ef41655','\0'),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','e3c658f5-9390-4b8d-a333-062a54a65ba5',''),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','e5c89cef-3d47-4a27-882c-9cd6cb52d7ff','\0'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','\0'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','32ad3d0c-d877-4811-bcfd-474b40ad1e8d',''),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','4277aaef-8983-44c7-81c6-d3c3485aa3fa','\0'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','608e02cb-3f63-4e89-9258-fbd1c7c6d8f0',''),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706',''),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','980ab3c2-627a-4b0f-82fe-3e9216cdda7f',''),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','\0'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','cecca841-4cd1-4f09-8724-fa20c73281b8','\0'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9',''),
('cf784c13-493e-4d43-86ee-8b9c81845b12','43bd3461-2d5e-412c-96cd-125e4e2785b5','\0'),
('cf784c13-493e-4d43-86ee-8b9c81845b12','564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d',''),
('cf784c13-493e-4d43-86ee-8b9c81845b12','5e701f0b-2581-4458-a171-fdf2aa34d1c9',''),
('cf784c13-493e-4d43-86ee-8b9c81845b12','7538c9cb-f57d-4358-a073-1eb9bcbe0f29','\0'),
('cf784c13-493e-4d43-86ee-8b9c81845b12','92fb03e0-4c6d-4b25-ac33-54ace6e61139',''),
('cf784c13-493e-4d43-86ee-8b9c81845b12','b9130729-e811-4118-9c3c-2fe95a93bd5a',''),
('cf784c13-493e-4d43-86ee-8b9c81845b12','c47be204-f074-4670-8bd3-fd526ef41655','\0'),
('cf784c13-493e-4d43-86ee-8b9c81845b12','e3c658f5-9390-4b8d-a333-062a54a65ba5',''),
('cf784c13-493e-4d43-86ee-8b9c81845b12','e5c89cef-3d47-4a27-882c-9cd6cb52d7ff','\0'),
('dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','43bd3461-2d5e-412c-96cd-125e4e2785b5','\0'),
('dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d',''),
('dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','5e701f0b-2581-4458-a171-fdf2aa34d1c9',''),
('dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','7538c9cb-f57d-4358-a073-1eb9bcbe0f29','\0'),
('dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','92fb03e0-4c6d-4b25-ac33-54ace6e61139',''),
('dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','b9130729-e811-4118-9c3c-2fe95a93bd5a',''),
('dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','c47be204-f074-4670-8bd3-fd526ef41655','\0'),
('dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','e3c658f5-9390-4b8d-a333-062a54a65ba5',''),
('dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','e5c89cef-3d47-4a27-882c-9cd6cb52d7ff','\0');
/*!40000 ALTER TABLE `CLIENT_SCOPE_CLIENT` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_SCOPE_ROLE_MAPPING`
--

DROP TABLE IF EXISTS `CLIENT_SCOPE_ROLE_MAPPING`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_SCOPE_ROLE_MAPPING` (
  `SCOPE_ID` varchar(36) NOT NULL,
  `ROLE_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`SCOPE_ID`,`ROLE_ID`),
  KEY `IDX_CLSCOPE_ROLE` (`SCOPE_ID`),
  KEY `IDX_ROLE_CLSCOPE` (`ROLE_ID`),
  CONSTRAINT `FK_CL_SCOPE_RM_SCOPE` FOREIGN KEY (`SCOPE_ID`) REFERENCES `CLIENT_SCOPE` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_SCOPE_ROLE_MAPPING`
--

LOCK TABLES `CLIENT_SCOPE_ROLE_MAPPING` WRITE;
/*!40000 ALTER TABLE `CLIENT_SCOPE_ROLE_MAPPING` DISABLE KEYS */;
INSERT INTO `CLIENT_SCOPE_ROLE_MAPPING` VALUES
('1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','cfce9bea-2fd5-40f2-8511-fb4d78b459b7'),
('43bd3461-2d5e-412c-96cd-125e4e2785b5','df5f87a1-976d-47e6-bec8-00d241ccb192');
/*!40000 ALTER TABLE `CLIENT_SCOPE_ROLE_MAPPING` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_SESSION`
--

DROP TABLE IF EXISTS `CLIENT_SESSION`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_SESSION` (
  `ID` varchar(36) NOT NULL,
  `CLIENT_ID` varchar(36) DEFAULT NULL,
  `REDIRECT_URI` varchar(255) DEFAULT NULL,
  `STATE` varchar(255) DEFAULT NULL,
  `TIMESTAMP` int(11) DEFAULT NULL,
  `SESSION_ID` varchar(36) DEFAULT NULL,
  `AUTH_METHOD` varchar(255) DEFAULT NULL,
  `REALM_ID` varchar(255) DEFAULT NULL,
  `AUTH_USER_ID` varchar(36) DEFAULT NULL,
  `CURRENT_ACTION` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_CLIENT_SESSION_SESSION` (`SESSION_ID`),
  CONSTRAINT `FK_B4AO2VCVAT6UKAU74WBWTFQO1` FOREIGN KEY (`SESSION_ID`) REFERENCES `USER_SESSION` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_SESSION`
--

LOCK TABLES `CLIENT_SESSION` WRITE;
/*!40000 ALTER TABLE `CLIENT_SESSION` DISABLE KEYS */;
/*!40000 ALTER TABLE `CLIENT_SESSION` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_SESSION_AUTH_STATUS`
--

DROP TABLE IF EXISTS `CLIENT_SESSION_AUTH_STATUS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_SESSION_AUTH_STATUS` (
  `AUTHENTICATOR` varchar(36) NOT NULL,
  `STATUS` int(11) DEFAULT NULL,
  `CLIENT_SESSION` varchar(36) NOT NULL,
  PRIMARY KEY (`CLIENT_SESSION`,`AUTHENTICATOR`),
  CONSTRAINT `AUTH_STATUS_CONSTRAINT` FOREIGN KEY (`CLIENT_SESSION`) REFERENCES `CLIENT_SESSION` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_SESSION_AUTH_STATUS`
--

LOCK TABLES `CLIENT_SESSION_AUTH_STATUS` WRITE;
/*!40000 ALTER TABLE `CLIENT_SESSION_AUTH_STATUS` DISABLE KEYS */;
/*!40000 ALTER TABLE `CLIENT_SESSION_AUTH_STATUS` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_SESSION_NOTE`
--

DROP TABLE IF EXISTS `CLIENT_SESSION_NOTE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_SESSION_NOTE` (
  `NAME` varchar(255) NOT NULL,
  `VALUE` varchar(255) DEFAULT NULL,
  `CLIENT_SESSION` varchar(36) NOT NULL,
  PRIMARY KEY (`CLIENT_SESSION`,`NAME`),
  CONSTRAINT `FK5EDFB00FF51C2736` FOREIGN KEY (`CLIENT_SESSION`) REFERENCES `CLIENT_SESSION` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_SESSION_NOTE`
--

LOCK TABLES `CLIENT_SESSION_NOTE` WRITE;
/*!40000 ALTER TABLE `CLIENT_SESSION_NOTE` DISABLE KEYS */;
/*!40000 ALTER TABLE `CLIENT_SESSION_NOTE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_SESSION_PROT_MAPPER`
--

DROP TABLE IF EXISTS `CLIENT_SESSION_PROT_MAPPER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_SESSION_PROT_MAPPER` (
  `PROTOCOL_MAPPER_ID` varchar(36) NOT NULL,
  `CLIENT_SESSION` varchar(36) NOT NULL,
  PRIMARY KEY (`CLIENT_SESSION`,`PROTOCOL_MAPPER_ID`),
  CONSTRAINT `FK_33A8SGQW18I532811V7O2DK89` FOREIGN KEY (`CLIENT_SESSION`) REFERENCES `CLIENT_SESSION` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_SESSION_PROT_MAPPER`
--

LOCK TABLES `CLIENT_SESSION_PROT_MAPPER` WRITE;
/*!40000 ALTER TABLE `CLIENT_SESSION_PROT_MAPPER` DISABLE KEYS */;
/*!40000 ALTER TABLE `CLIENT_SESSION_PROT_MAPPER` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_SESSION_ROLE`
--

DROP TABLE IF EXISTS `CLIENT_SESSION_ROLE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_SESSION_ROLE` (
  `ROLE_ID` varchar(255) NOT NULL,
  `CLIENT_SESSION` varchar(36) NOT NULL,
  PRIMARY KEY (`CLIENT_SESSION`,`ROLE_ID`),
  CONSTRAINT `FK_11B7SGQW18I532811V7O2DV76` FOREIGN KEY (`CLIENT_SESSION`) REFERENCES `CLIENT_SESSION` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_SESSION_ROLE`
--

LOCK TABLES `CLIENT_SESSION_ROLE` WRITE;
/*!40000 ALTER TABLE `CLIENT_SESSION_ROLE` DISABLE KEYS */;
/*!40000 ALTER TABLE `CLIENT_SESSION_ROLE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CLIENT_USER_SESSION_NOTE`
--

DROP TABLE IF EXISTS `CLIENT_USER_SESSION_NOTE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CLIENT_USER_SESSION_NOTE` (
  `NAME` varchar(255) NOT NULL,
  `VALUE` text DEFAULT NULL,
  `CLIENT_SESSION` varchar(36) NOT NULL,
  PRIMARY KEY (`CLIENT_SESSION`,`NAME`),
  CONSTRAINT `FK_CL_USR_SES_NOTE` FOREIGN KEY (`CLIENT_SESSION`) REFERENCES `CLIENT_SESSION` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CLIENT_USER_SESSION_NOTE`
--

LOCK TABLES `CLIENT_USER_SESSION_NOTE` WRITE;
/*!40000 ALTER TABLE `CLIENT_USER_SESSION_NOTE` DISABLE KEYS */;
/*!40000 ALTER TABLE `CLIENT_USER_SESSION_NOTE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `COMPONENT`
--

DROP TABLE IF EXISTS `COMPONENT`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `COMPONENT` (
  `ID` varchar(36) NOT NULL,
  `NAME` varchar(255) DEFAULT NULL,
  `PARENT_ID` varchar(36) DEFAULT NULL,
  `PROVIDER_ID` varchar(36) DEFAULT NULL,
  `PROVIDER_TYPE` varchar(255) DEFAULT NULL,
  `REALM_ID` varchar(36) DEFAULT NULL,
  `SUB_TYPE` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_COMPONENT_REALM` (`REALM_ID`),
  KEY `IDX_COMPONENT_PROVIDER_TYPE` (`PROVIDER_TYPE`),
  CONSTRAINT `FK_COMPONENT_REALM` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `COMPONENT`
--

LOCK TABLES `COMPONENT` WRITE;
/*!40000 ALTER TABLE `COMPONENT` DISABLE KEYS */;
INSERT INTO `COMPONENT` VALUES
('0a969c3e-dc44-4daf-84d7-2216b37e8c88','Max Clients Limit','dab18c5a-b240-4256-b8a9-31247dda96ac','max-clients','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','dab18c5a-b240-4256-b8a9-31247dda96ac','anonymous'),
('210c9923-7635-4f00-af9a-9581abcfcc7a','Trusted Hosts','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','trusted-hosts','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','anonymous'),
('2615bb3e-7652-412a-80fb-9d566aefff55','Allowed Protocol Mapper Types','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','allowed-protocol-mappers','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','anonymous'),
('27fdcb0e-f619-447c-b60a-d150586f71ce','Allowed Client Scopes','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','allowed-client-templates','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','authenticated'),
('29e059a7-e37b-45e7-8bc2-41845993b53c','aes-generated','dab18c5a-b240-4256-b8a9-31247dda96ac','aes-generated','org.keycloak.keys.KeyProvider','dab18c5a-b240-4256-b8a9-31247dda96ac',NULL),
('3cf4ca02-320a-4d4b-9de1-61ad59fb1060','Full Scope Disabled','dab18c5a-b240-4256-b8a9-31247dda96ac','scope','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','dab18c5a-b240-4256-b8a9-31247dda96ac','anonymous'),
('46bc5eb2-0fb5-4955-8a0f-dfabaa48953e','aes-generated','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','aes-generated','org.keycloak.keys.KeyProvider','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',NULL),
('473a4602-fa1d-487d-b062-ffad9346c6fc','Allowed Protocol Mapper Types','dab18c5a-b240-4256-b8a9-31247dda96ac','allowed-protocol-mappers','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','dab18c5a-b240-4256-b8a9-31247dda96ac','authenticated'),
('542ee7c3-3850-4998-b682-0292692e6f42','Allowed Client Scopes','dab18c5a-b240-4256-b8a9-31247dda96ac','allowed-client-templates','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','dab18c5a-b240-4256-b8a9-31247dda96ac','anonymous'),
('56b276b0-e444-416e-8647-342012790c61','hmac-generated','dab18c5a-b240-4256-b8a9-31247dda96ac','hmac-generated','org.keycloak.keys.KeyProvider','dab18c5a-b240-4256-b8a9-31247dda96ac',NULL),
('62f3fc4a-3a69-4707-912b-60848a196818','Allowed Protocol Mapper Types','dab18c5a-b240-4256-b8a9-31247dda96ac','allowed-protocol-mappers','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','dab18c5a-b240-4256-b8a9-31247dda96ac','anonymous'),
('63cb5b4f-f220-4c5d-ba77-9e188bdd0ef6','Full Scope Disabled','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','scope','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','anonymous'),
('6913cb47-4449-4dfb-bb66-82ebf0efe02d','Max Clients Limit','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','max-clients','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','anonymous'),
('754f8672-04e4-4e01-9ebe-dc4528c8ff2e','rsa-enc-generated','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','rsa-enc-generated','org.keycloak.keys.KeyProvider','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',NULL),
('8a510298-9577-4984-a48e-286db607aecc','Allowed Protocol Mapper Types','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','allowed-protocol-mappers','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','authenticated'),
('ac8c8bca-32eb-4f5e-bac0-6531cccbf3ee','rsa-enc-generated','dab18c5a-b240-4256-b8a9-31247dda96ac','rsa-enc-generated','org.keycloak.keys.KeyProvider','dab18c5a-b240-4256-b8a9-31247dda96ac',NULL),
('ae21c5ad-c482-47a2-ad55-c27b973ee008','Consent Required','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','consent-required','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','anonymous'),
('b8b99e09-4896-4151-888d-be70c91d2326','Allowed Client Scopes','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','allowed-client-templates','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','anonymous'),
('bd83a7b3-3a4b-4f2f-b089-9cc779b9dda2','Trusted Hosts','dab18c5a-b240-4256-b8a9-31247dda96ac','trusted-hosts','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','dab18c5a-b240-4256-b8a9-31247dda96ac','anonymous'),
('cbe7233f-b58f-47d4-9036-d6861a330756','Allowed Client Scopes','dab18c5a-b240-4256-b8a9-31247dda96ac','allowed-client-templates','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','dab18c5a-b240-4256-b8a9-31247dda96ac','authenticated'),
('d46bc997-8cc2-45b8-875f-6dfc90dc6d29','rsa-generated','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','rsa-generated','org.keycloak.keys.KeyProvider','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',NULL),
('e6bb5632-7783-42c4-96f2-51089cfaf746',NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','declarative-user-profile','org.keycloak.userprofile.UserProfileProvider','dab18c5a-b240-4256-b8a9-31247dda96ac',NULL),
('e6e505d0-75d2-45db-a880-e53465ddc49f','rsa-generated','dab18c5a-b240-4256-b8a9-31247dda96ac','rsa-generated','org.keycloak.keys.KeyProvider','dab18c5a-b240-4256-b8a9-31247dda96ac',NULL),
('f6edefda-f365-4f99-8b98-aa37a6969ffb','Consent Required','dab18c5a-b240-4256-b8a9-31247dda96ac','consent-required','org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy','dab18c5a-b240-4256-b8a9-31247dda96ac','anonymous'),
('ff236f10-59e1-4d4c-9133-a9f1beec9833','hmac-generated','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','hmac-generated','org.keycloak.keys.KeyProvider','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',NULL);
/*!40000 ALTER TABLE `COMPONENT` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `COMPONENT_CONFIG`
--

DROP TABLE IF EXISTS `COMPONENT_CONFIG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `COMPONENT_CONFIG` (
  `ID` varchar(36) NOT NULL,
  `COMPONENT_ID` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `VALUE` longtext CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_COMPO_CONFIG_COMPO` (`COMPONENT_ID`),
  CONSTRAINT `FK_COMPONENT_CONFIG` FOREIGN KEY (`COMPONENT_ID`) REFERENCES `COMPONENT` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `COMPONENT_CONFIG`
--

LOCK TABLES `COMPONENT_CONFIG` WRITE;
/*!40000 ALTER TABLE `COMPONENT_CONFIG` DISABLE KEYS */;
INSERT INTO `COMPONENT_CONFIG` VALUES
('0093de47-02aa-4e64-8348-8a6c3b9e32ba','2615bb3e-7652-412a-80fb-9d566aefff55','allowed-protocol-mapper-types','saml-user-attribute-mapper'),
('01a7640c-5666-4f3b-8824-cce4ead9031c','473a4602-fa1d-487d-b062-ffad9346c6fc','allowed-protocol-mapper-types','saml-role-list-mapper'),
('0ac3808a-b7de-4644-9afb-86f87462a48e','210c9923-7635-4f00-af9a-9581abcfcc7a','client-uris-must-match','true'),
('0ace74a4-9614-4b01-bd6c-2fcb66787ff8','62f3fc4a-3a69-4707-912b-60848a196818','allowed-protocol-mapper-types','oidc-usermodel-property-mapper'),
('0eac78b0-06ac-4a12-9a8e-ccfb4d1931ce','56b276b0-e444-416e-8647-342012790c61','secret','TWqXoH_uR4TJaY3NGvT7EITCqaq0henBtcXtbanv-ZFKEprxa3xJ4ERP8WK9JU4X71ywTJ4Ez2R45yHA--5qVQ'),
('1115d631-913c-4a8f-91a4-af0aad227726','754f8672-04e4-4e01-9ebe-dc4528c8ff2e','algorithm','RSA-OAEP'),
('12226873-0b97-4ee0-972c-b3730d1c52ed','e6e505d0-75d2-45db-a880-e53465ddc49f','certificate','MIICozCCAYsCBgGV6oylLzANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDDApjb250cmFiYXNzMB4XDTI1MDMzMTA0NTIyMFoXDTM1MDMzMTA0NTQwMFowFTETMBEGA1UEAwwKY29udHJhYmFzczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAIRwHKrQyIYYkyNijv2CvuVGjY9tN6GqSlHAMY8s815349rgH+hLxASJN6L97O+Llu8uQfhurJZNwWf3i48kZV8c9OlQMN5Tl5Y0ziFBEZsSHc/0R1nYwbGwYQfLwlokAxl4QSuuhXwKIP9+MM7jnLbc/zk9kEfqeoZheFzDnnC3RJGpHZzWttw/b1lPTO6GFhMHmcZbOSiPC5gJPtmEpUEST0BGEftVzKNJgUDi1NlyVIVN4t6thdr7qglXSGbsBqwjtEdPsFLsgY8CnpVH8CWHiwMHAJIOQW8oRv4oLEyir0cIRgOJd6Z8jZHpG7PbmaY6ZKXztxb/ecSoJ/6lurMCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAWLCthHlY15neG9erh6g9EdXKORRQ3k2WGoarUWFFEhr/aUfWu+k1N0L0L4ZVkyApBOfIr/+VLnfS2WtLUlgMpM9PF3XKKQHb5cYxbjcTcnxmpv6sLSwrZambkSugb8ClMNN80Ya/BpSL/XxHiD936ALP8xHBPJZsbhOWZUBA8eX8bG5A0x7B+9XIxVfGBs2r3iwpPtxkJtAjecCk4wKpcTStHNiIv/X5SxOQoEEoXloI+pdUaJTB56dZjTI2Zv8li+Whtdqb4jP6+Ivrn1hAsUbelbyBqa5+m7SEBEwDGw8tn2RcRmPa92qtAk1RakhSchu/2gd8yRQFrM8sqKSHWg=='),
('14ea2706-43be-4929-9ce7-d78d6023a891','62f3fc4a-3a69-4707-912b-60848a196818','allowed-protocol-mapper-types','saml-user-property-mapper'),
('184a647d-b278-49f1-a37a-c27c0c56c320','8a510298-9577-4984-a48e-286db607aecc','allowed-protocol-mapper-types','oidc-address-mapper'),
('18fd5840-a49d-425d-89e7-2469a5fb7758','ac8c8bca-32eb-4f5e-bac0-6531cccbf3ee','priority','100'),
('1dbb6aa0-ac07-4e92-8a1a-745a30539975','473a4602-fa1d-487d-b062-ffad9346c6fc','allowed-protocol-mapper-types','oidc-usermodel-property-mapper'),
('222a0c46-b35f-47e9-9725-0aab4b0ff7be','e6e505d0-75d2-45db-a880-e53465ddc49f','privateKey','MIIEowIBAAKCAQEAhHAcqtDIhhiTI2KO/YK+5UaNj203oapKUcAxjyzzXnfj2uAf6EvEBIk3ov3s74uW7y5B+G6slk3BZ/eLjyRlXxz06VAw3lOXljTOIUERmxIdz/RHWdjBsbBhB8vCWiQDGXhBK66FfAog/34wzuOcttz/OT2QR+p6hmF4XMOecLdEkakdnNa23D9vWU9M7oYWEweZxls5KI8LmAk+2YSlQRJPQEYR+1XMo0mBQOLU2XJUhU3i3q2F2vuqCVdIZuwGrCO0R0+wUuyBjwKelUfwJYeLAwcAkg5BbyhG/igsTKKvRwhGA4l3pnyNkekbs9uZpjpkpfO3Fv95xKgn/qW6swIDAQABAoIBACNFsrThx05DlEiL0tZ88Hei60fkSDlD3+hW/jwKNkUWPDbKk2TsbOfiXdGIvIZuEIRiNwrB+zBKxDR67w3wHRmQXkAXbfSAofJM3QtpR5Wb5RnCDxDEVI4NEkKfx4L3bWXmq8DFCeMn1XMGelxXraDcShNGLLuinQBWTFa0eOm+26p/Zt7bYoQb5TkVzifVo36FCqdilZuDaQ4n0VHnGLGiyra2+00W6fgd12ly4Z7mGqRWF5C7+nbFmJDxiO5VUU39ARI8dzCs4DPhkJJaJwUnnw1amVXRQkhusmC35jVT6USUR7OStyEI86//ent51n9UlEMbv9ToWQMOTHYfMYECgYEAus/9dSmsaGGQsgbTcG6DASFJTXH6/afStpdoj/wfqaL2++BuEDttCaSWtYYq9NXnG+e8/Z6+ebAi3Bt/envD2HNMvAmzKWmtDsGPLh7FuS07wPCVpNVL+nLBokOo8jJZ6zVaKtFOWd+Hcq6zjOIkjxB8Mbf7yAXiLGFaBPA9MDMCgYEAtXzHsCGk2yevW6ZJ+fEAARry7VWcm6gHCxEOZdBmp0m42Sn6OVme1zSHK1ZdRx3eBXz84WydgUyhegUw3qmdebqkkvLp0lUkemkp1cvhWEfj4yrJjcYmy0i9z3uyih0RtKeNFl2dwvjQ0twuceAIR9aEcKqTJwhe13Yw/nMIy4ECgYB1folYHjzMbci236ouhaMpm8jhx7Vnwhy6MKJYJOe5JsEWjAJNfULIFNehFeCAmuQ/XdI05ZnBKXHTZAwaeiskQOhbP/KKMmfg5wZpqHsNS5DQecB0qp6dx31X1Bw3MEnzsFukoH4Z8ofbLlvJWRZLUL/7+U6HcIPfC9+1SXAClwKBgAS618lzVwSPKDbPQqZM7Z8ZwLMGxCoaWvSi4SkuIT7C4Rpnyams+ELLj6pFefDcimjCNST626/++0Ze1EM5UG1Xu+pIgmeE6Ip4KyrzQVA3r2zANLiJLYGmx6ucoa6Py2JV64tlrTLjoS2dp2g4Wn7kzFbTWzptMWuUHPrErLoBAoGBAJuQUBjE+pYg6glAjydpD4gS9XJE1dkrXK8kUuGZaWYkuxp6A9C1KrxJd7DJ7ZTqvf1vw5jO6k0ZN+xThtfPySXHs0ISStAg41+TsHqr7KNwW3dnHMO8qDcM8IWhg0oInqXyvt7JUok+hPYBAFwyqHWaLeZs0rRlEJ4eqCfj3J7w'),
('2755130c-1ceb-4308-9edd-e48f51c6634d','2615bb3e-7652-412a-80fb-9d566aefff55','allowed-protocol-mapper-types','oidc-address-mapper'),
('27ba83e3-3d51-4f5c-b05c-d4abef8785a3','6913cb47-4449-4dfb-bb66-82ebf0efe02d','max-clients','200'),
('27fa3110-adf4-4e94-9f06-ab24e923fc1a','473a4602-fa1d-487d-b062-ffad9346c6fc','allowed-protocol-mapper-types','saml-user-attribute-mapper'),
('2ce13829-63dd-437c-958a-86604533e7c8','754f8672-04e4-4e01-9ebe-dc4528c8ff2e','privateKey','MIIEowIBAAKCAQEAuS6t2r+Uc5jJ+S23zlBKa73qf5mZu2P/Kl59yvvaZJtHYG2fCGvufd0BKLyBTorvfK2etYFgPZvYegkWSt0aztiW/pF0gG0RrTyBudIQoBhet5uWneYO9vLyqLq0nQwrXvViN8wz24kXlyU/lzeWnHf85QA08/z5a41hUHKx4ZzFkj/2x82fJ+iD64xmyn0wamCutLBT82rBdd9pjxi+61hkTCVCjGM1jBsuEFvcQUTluFnuiyY1wnD44271cc/iK3vXrq2tA+wK70TgTV6ONdHr6+7dnyT+XleAmKmtZtxZqRCF7pyjyHtYKfgvMXf/COc9O1T5D2Fc5tNRm6I4/QIDAQABAoIBADUT6JgA/ottmUKXNI5pnBMqscqWG6bHAC3EPLkQHCZnDXvZn9I5oXeo/3qOIWACWad6Wjm7FftCrrc34JBftJ3iHdFknqhq2ry1UZeR2tsQcSGecnrapKJqu1vafAdhpBLJMbg9iwWbU0wqzIHK2JwLlkyLFSJz+Ye209RLs6mvGWkLXHyodoweB38NDRBq/fxM0ZySRg+1wAGHYHiNvrc9syNgOFHgPPSb9UGh7EKANb+pdfbh6jNTB3z6son/y4vpxBAONkv+F8dontWVmj+BTal9t1qA8sgkVzcO+YBEmgt4ZSeqF2kd2rEHObTq//uIy365jLwedflnmsR7Tq8CgYEA3g/Byh9YKMkM9cNSr8nP/gUHXEgc/rDbJSdhMSqJAYQA5ZoBct13rJZRLm+QY1quDbEr0URazihO2bDtOR3U5dDZsSHxx+Ap4dY0rGNGkMHVdezADjNr5zsvuVrmv1/kjqHzb4bZU3I5P/qrhCQIqrURYYoXevkdF4iU5jc9n+sCgYEA1XwCSU3rkaH9SJ/qO7jLJXHv8VMEbOKC96jrCrt3R8BJqfNvTyPne57A3NV8bEuvHoPgNqlLX3Z3CsZ1nPJBIveEhCooM2roAKR0WMMvlvQXUee5NRIq6OG88sVy16/sQKN/qnLB8XKGwZlnRi5Up0g/YaFuSf9a28j48nXsuLcCgYBs226VZf4yqDRpOeIL+LO0g8SS8Wr9U7dqJD7Z+k8FZi+GXpO9OmITQfD0AY7XlbljTun7ATY+f7X/s2LnL/+Q1WwSEGDVKcd+RSK3K0eJaOv6jh+sFnsb9IC1raEWSaziWvPaRVG+PW1hNsHj2kJBZNfrZ+WQzBP92F+d55CXFwKBgF3xJvRo9HtuZA2cSS+knshIfgScunrLpkQjMeLUIaYSSJgfxmB19Twh3M6QpyLknxf3gierkb5dW/8C2+iHdgBUGR0ri+ssZRE7TPNuWLe9i7GAHbDr4LP/+ex+1I1zHaxIBjrUKuH7uq7guWBZrOi70yA8MFMhqjLDGkFfgR67AoGBAIxyVPuhs/P80l7NIulO/1l5b1opfrZXzSgk8ua2UoEsCuV6xOLz6/H4ADn4Yn+bZLVQ/cQ3483s9qWm0iR7KzoMOXCsJZFTZmgZ9OM4EUiwQlnOUprQe28z7RRG841gAxxCSYUfcCklFcMnZm1zg4Anpbkk+HIYwytutSw5QkYS'),
('334a1fa8-fdac-48e9-bb9e-c1f02f55c913','29e059a7-e37b-45e7-8bc2-41845993b53c','secret','IDoW2-4EmjhHAuvYPiZFqQ'),
('33f41f11-708c-4c04-883b-db7082993e40','62f3fc4a-3a69-4707-912b-60848a196818','allowed-protocol-mapper-types','oidc-address-mapper'),
('36c2049b-3bba-488d-b3ba-7c8026edd26b','ac8c8bca-32eb-4f5e-bac0-6531cccbf3ee','algorithm','RSA-OAEP'),
('37e6a0df-9e50-4e4e-a134-9ef39b16a126','56b276b0-e444-416e-8647-342012790c61','kid','665bc983-253b-4cb2-8f6e-f5cd24bf7ca2'),
('3b5ce583-9d41-431c-aa22-29646ad7cc02','62f3fc4a-3a69-4707-912b-60848a196818','allowed-protocol-mapper-types','saml-user-attribute-mapper'),
('3b6a0755-b558-48e8-a5bc-a69cf0130055','bd83a7b3-3a4b-4f2f-b089-9cc779b9dda2','client-uris-must-match','true'),
('3cf73714-745f-4e41-94fa-7d9e914d544e','754f8672-04e4-4e01-9ebe-dc4528c8ff2e','priority','100'),
('409d2a75-aa43-4bac-a8af-9d98bb25bcf0','b8b99e09-4896-4151-888d-be70c91d2326','allow-default-scopes','true'),
('417dccec-7a43-4214-8763-62ac09c5154c','ac8c8bca-32eb-4f5e-bac0-6531cccbf3ee','privateKey','MIIEpAIBAAKCAQEA3Dnec6POofdw1f2pH2J2VrRjAAhH05isyBAFzx/kEzBgPOV68Ekwdppjn/aepfkYc3gsGCXDC3vcXE4SuAjsrebByj3Ew8FvucFPFs+ikl3d5/YN8W/7AKWVCoyg5KrBqaa8of4KvVAiepX2Xf2SYuX5gbdtVoK963EFF1HO6Ed3KImtG/cuVHf5oYiPU1dtxJ++ttFELLNYSJJWgJJz/0G8cYaG6U7CIXsa+e3CZHeRcoXoOUMO7uigKqc5hKD9oAKCL3uTfGrQb/Lp2NZV7wcaXRb5og19urYyjihSScSXglMF2sPC6Q7YTfrpfgtsTdbAsciLtleyuZcJPt1P2wIDAQABAoIBACiMJReQkPKETwuvXQywwc4b/2BZpfPhF+rr/E3S9tjLnuSHcfe82gX0TiR9MV+oueZEuYWmqj86imuaWlr1FbK9GnAkqE5MlsgSPgAasbmWO83CIXYTIplPY14iX1tKz0Zvsyp2Tj7l+rssUkSi8+luo15NSf3UK6imUgQlpV1ht7AXIwGi8QZgRofKo35VtiCjTMnhgD7j7Sr6YrYwOPC+ssvfkgYqLj+xDb9JLhduI9yA1v/WWJvIZA5v710fP2Oz7ZpP2Nt7I8mgtn1js+U/PWwgWOdek4NpBrV6DsvLV8MOtnDSj9A06gD677VNv90EI92cQWblKOaT9pl8etUCgYEA73jehVQvOz4OurSA7WbZEdXK0ZSPmF5z+phg/8AW6FvLD5KAFTBzuFgV+6gzz2G3xGGOZHs7zjXldpIIZm++kVsZrZoN8QgfzE0EPlTMVBtSJimFREFNkTYw5q3RuHHOzdKcxKKZ7wcAKVRFbMOH7c/528rS9GVg4VhTclFXxKcCgYEA62zy34uoHKR54YWnBT73LE6G6Cpdi8L1A5uvwnO/ICOSb2sQCTKZEdSG4L8rXw9ua/rbEyg3bKL4HMvNuehp8u/xuVOz8KYLRz8xEqS3x4byAmBcTBRaJ4Tb+0GgzBtcEV2uhYtD9m1dp5rtxMWvRPAxzVjth2FJ0XshAQzVna0CgYAhdL2B2xUOLclZBEbO5AOHnlrLlPnKy8dgR1Gl6WxJ4ikob8s9KpvAMW5AzmsOmhRWd1qxZxYf5R+9xQEvboUtQZEA0/kGp5/ppwjkvGwfhAGiG0LnGkh/9RY35Cjcn+nIj5gfUKg44L2BCKj6XQbsjpXVwyxdwJwcX36pBfxBGQKBgQCQJ1D8Aqa4ixm6Nr1TX/+3WIoQpMhM6N5gDDdtyLPx+PYUVSkniJzjpw/DlCr5dRh2886rB0gQtCVadIyO1jnxsGyBvzgCFZn4UUA6GzQQ75dGTzyUtS2S3y5XxhKwh9wzIfrX+LNvs/3Rv/LxNt6gRrcn9tjSuYaax1spKnOurQKBgQCeA3PrXmeEDGF6WCdalBrPcOHFL43FYSeX5sqftFm04NW/44eHYqg2HSOhez1mZJQBTDGC+oMPjv+vOH9e7qZSM3apdPlp0pTU9eJSHQ2+3B68q/Ml00SpbhOtXDD/GsZxLePUgvUAd1rniAoiPlvwHKKT0vOOlnS0QJhowog0tA=='),
('476cabf2-874d-4701-aa71-d30c8a44b7e1','d46bc997-8cc2-45b8-875f-6dfc90dc6d29','privateKey','MIIEpAIBAAKCAQEA1f5E5aaRsIQQkz48BCuFZ4008NsnHQc+jPrUlG6cFbac74YbImjAbmeh4Kba9rOP4vJm09jZFQgmfBT/b9HU89q98yVoLR3E41ANaUQRbMz9TbJVcKW60zzvyo73N4Q0w6gbVIDSTBzalNchIu+31rCIv/PIPq9zLHkLocgdOlOkjj7RHkK7nDAvslM3bH+h0NeDljqHW3wTfH2RXxN9nXswlyErEHkuWS0gPLERp9bLmQTAv9qhf0SY/Ez+r/L2jS78Hoe5D6GVL+uX/mhC1tJw292nYI5sKx9lzc+uNKLBjPQ2Ubq6b6+/vGUZpHuOchhRAi75ZMiM+V9Z4leoWQIDAQABAoIBACXGFwJUx1XZ0hUzwKNZzVgsmGJFxR8+Jp/7LOgwqDO7AvPS/9owlHtIps4BlhhDNQxyDo2psxQf1q9Dg52I9CbBf5M6kKuaHCWl/WAOCGdkvffnmWZjktlz4b4nQ2NU3n2FIKHnhXezBjCM0wgYOaLXkaQUk83g6Zs5mMCLkwE27NVYFOkv+q8/bP2EvZL1+yNOuVut5SrMhvCHriisi5ZVk24BO8/iWsKdMQP1EYoNOLleKhWeLDNNMHjLxh9pMTMTlXZzjobbVwZ9th2AOy3Vz5oS8YLu3OhmDXCZ+DXNICXrgSWB1Hg0mT+X5XsmuaX0OzwOk9ATjS/MqIjZGdsCgYEA9WT7fkoidCProD8mEufENwv+j33Ep7YENWFeKkwG8wfXSmVoxL+0mPc8NYE+Wbq+M9Cm+xFMXHaHqvrQ4W+mXPsA5Etzz428NxHrrlULkzpp9NAle5Z6sxvM10kiLi6KDMI6XXrWWUuMHHdMA3DF9iIQtgiqAxJDvw7+FNkTNLcCgYEA3z3d9KyxzX1J5jVGuMdZtDskMx8JyaJ80bk1woaljAO3tb2pLc5sj9+GSQKArpXE32EXqxwT7BCYpKBMtF3NJSe40breP+mHf7DSGm3nmN80deV9j3NHUf/BbUbq4+iL+kPbZ35/hAbfPOWKoRgN9fKgKK7LMQ9+K779Aa+vm28CgYB+NC4neCcaBfNDmdaR+IJwMQn9cBg4jKLDdU0BgdI9ITY2+8qTDWjrFpPvjIWtjh4N9ew6yV21W/xQEehlWI992FVQFAH+p4054UyNfw2R7YPatUXhtrVp8g06V1Ft4N98ylNMCkW87N6lMTF1v4UAHersQ650H+uZkjNYM3/uJwKBgQCcz6VgYApJMK+/MD8sPoPJcR2ddzj11NherP2RVellb5sU41O6JFzntvhpwoNHn1Z6HoZ0oDVyRbojMaKPs7ANYFiXoe7J8C1IyZjcDcV4AZmlEv3ezPgVJlTlgMIwM0JYGmA804OY5wbajNaTEAWGdNaBnT6HiL101yR7kcAFqwKBgQC6WaSeiW+RDeotyU+nr08rV3ujus5CIl5wnWEWhqjBm8s5D58Qqg2PMcZ6e8fA4iD/qVyHzOQiYk3m2h/3n+QEYrVgULRECh6bUZYwJXO08PFfysQh5AMlPeBnQdP1k/nUymlBCvxB1RJ1PhOpyiZlXPzBfPbYUFfBOOwf8f8Zqw=='),
('4a9ecb7a-8e3b-4cdd-a573-47d19333728a','8a510298-9577-4984-a48e-286db607aecc','allowed-protocol-mapper-types','saml-role-list-mapper'),
('4c5f4132-cbb6-49af-8a03-5c32b0bcf95a','ff236f10-59e1-4d4c-9133-a9f1beec9833','secret','ll6e3TrZEUcY8IKRe7IJjH6J68TUHow6-wiBGz_Fkx2RkT690o35xv5MHAzMPPPZ5AAdWPCGAARYib5Vq7OTkA'),
('5442aa88-31d6-46aa-8520-837e188dbb27','473a4602-fa1d-487d-b062-ffad9346c6fc','allowed-protocol-mapper-types','oidc-sha256-pairwise-sub-mapper'),
('5a7cfa87-a959-42c9-b3cc-aa9f03c60855','8a510298-9577-4984-a48e-286db607aecc','allowed-protocol-mapper-types','saml-user-attribute-mapper'),
('5ddefab8-7e41-48e7-a14b-be6f33859ea4','ac8c8bca-32eb-4f5e-bac0-6531cccbf3ee','certificate','MIICozCCAYsCBgGV6oydxDANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDDApjb250cmFiYXNzMB4XDTI1MDMzMTA0NTIxOFoXDTM1MDMzMTA0NTM1OFowFTETMBEGA1UEAwwKY29udHJhYmFzczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANw53nOjzqH3cNX9qR9idla0YwAIR9OYrMgQBc8f5BMwYDzlevBJMHaaY5/2nqX5GHN4LBglwwt73FxOErgI7K3mwco9xMPBb7nBTxbPopJd3ef2DfFv+wCllQqMoOSqwammvKH+Cr1QInqV9l39kmLl+YG3bVaCvetxBRdRzuhHdyiJrRv3LlR3+aGIj1NXbcSfvrbRRCyzWEiSVoCSc/9BvHGGhulOwiF7GvntwmR3kXKF6DlDDu7ooCqnOYSg/aACgi97k3xq0G/y6djWVe8HGl0W+aINfbq2Mo4oUknEl4JTBdrDwukO2E366X4LbE3WwLHIi7ZXsrmXCT7dT9sCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAebgujrVSXFWJ5ZQQgMtblMXWSF2eVCYZ4e3ZAOFejQWIct/gysmuONz4zh+f1nBXdJpbAFdh309q+50a53Y6nJAYOSHWcBPJRt/flG3zi5+t57EDU6/HC2f/qXWOrpX1aoiH48kBWi2lTq+And6FV/nH4ubUQLTpKvzvVNgKLFg5v/EchwwYQpDgsIytmGCHIc4p3hPdxwks7AqCjph582Zbi7+v8Wj+UbIKZDDB+sO2octJHvxwCdSwRH5zzevHguLHy7Yc7fkr/Zt/0LbYZp9U60tMRfT7jRmU1j5KtQLItoO+IsbLhxqgziYbF0fBWk63bQcSqm8ek9J5FQ/qeg=='),
('67449515-6ee1-4feb-80c0-78d85347733d','8a510298-9577-4984-a48e-286db607aecc','allowed-protocol-mapper-types','oidc-usermodel-property-mapper'),
('6a2556cf-05c4-4e6e-ad05-16436815e5d2','8a510298-9577-4984-a48e-286db607aecc','allowed-protocol-mapper-types','oidc-sha256-pairwise-sub-mapper'),
('6bf0afc0-df32-4db1-b32f-c44bab24f8a5','d46bc997-8cc2-45b8-875f-6dfc90dc6d29','certificate','MIICmzCCAYMCBgGV6oxVBzANBgkqhkiG9w0BAQsFADARMQ8wDQYDVQQDDAZtYXN0ZXIwHhcNMjUwMzMxMDQ1MjAwWhcNMzUwMzMxMDQ1MzQwWjARMQ8wDQYDVQQDDAZtYXN0ZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDV/kTlppGwhBCTPjwEK4VnjTTw2ycdBz6M+tSUbpwVtpzvhhsiaMBuZ6Hgptr2s4/i8mbT2NkVCCZ8FP9v0dTz2r3zJWgtHcTjUA1pRBFszP1NslVwpbrTPO/Kjvc3hDTDqBtUgNJMHNqU1yEi77fWsIi/88g+r3MseQuhyB06U6SOPtEeQrucMC+yUzdsf6HQ14OWOodbfBN8fZFfE32dezCXISsQeS5ZLSA8sRGn1suZBMC/2qF/RJj8TP6v8vaNLvweh7kPoZUv65f+aELW0nDb3adgjmwrH2XNz640osGM9DZRurpvr7+8ZRmke45yGFECLvlkyIz5X1niV6hZAgMBAAEwDQYJKoZIhvcNAQELBQADggEBAEO6NH5nAhLWRSrjoROtbun0c0/LYn79gQaYbWjDJ4unZLWcikfIh8chlPqetOCOAUtXb2LobxewBlHnaJPAfvPDbMti7Xw4lS5t1JOqHqR/ubcl2Ub6gAk4ssI99f8yDUA2XA8Ec7sYJQFVPDJaMnx0ywwIBiMNXCCN+HrUUB6tDQRJ8WuK41VHnG/fowX9gJlc2tF3Ot+Bkd8wxTPtmN2U0FKuoPJP2okZwJFTfMTcIS2wK6epTJMhBoZQ2aySKZAau+ko7sPoa0kJtFNwElCzLwixgA2fTk0mgW6Q7JENijV/qYu7dZsqQNG/NYh6PFlPZfVctQypYcofqSYaUtc='),
('7175835c-073d-49d3-b3cd-9f4cad6883ad','e6e505d0-75d2-45db-a880-e53465ddc49f','priority','100'),
('759b3e84-5b73-4dca-98ca-e2b214c18283','d46bc997-8cc2-45b8-875f-6dfc90dc6d29','priority','100'),
('7831c579-1c34-4950-bdeb-42fb5025e47d','62f3fc4a-3a69-4707-912b-60848a196818','allowed-protocol-mapper-types','saml-role-list-mapper'),
('8010471e-caf1-4221-9e1a-8aeb296728c6','29e059a7-e37b-45e7-8bc2-41845993b53c','priority','100'),
('856a14b4-8b46-44ba-91b2-c3e882e0d554','2615bb3e-7652-412a-80fb-9d566aefff55','allowed-protocol-mapper-types','saml-role-list-mapper'),
('86cf0aa8-fbfb-40d2-bead-2036d441fafd','542ee7c3-3850-4998-b682-0292692e6f42','allow-default-scopes','true'),
('8dbc245e-0ced-4c6b-ae4f-06907679ebf7','ff236f10-59e1-4d4c-9133-a9f1beec9833','algorithm','HS256'),
('8ec9cd65-9d67-4a0f-92e1-fd7809d53f30','754f8672-04e4-4e01-9ebe-dc4528c8ff2e','certificate','MIICmzCCAYMCBgGV6oxYrDANBgkqhkiG9w0BAQsFADARMQ8wDQYDVQQDDAZtYXN0ZXIwHhcNMjUwMzMxMDQ1MjAxWhcNMzUwMzMxMDQ1MzQxWjARMQ8wDQYDVQQDDAZtYXN0ZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC5Lq3av5RzmMn5LbfOUEprvep/mZm7Y/8qXn3K+9pkm0dgbZ8Ia+593QEovIFOiu98rZ61gWA9m9h6CRZK3RrO2Jb+kXSAbRGtPIG50hCgGF63m5ad5g728vKourSdDCte9WI3zDPbiReXJT+XN5acd/zlADTz/PlrjWFQcrHhnMWSP/bHzZ8n6IPrjGbKfTBqYK60sFPzasF132mPGL7rWGRMJUKMYzWMGy4QW9xBROW4We6LJjXCcPjjbvVxz+Ire9eura0D7ArvROBNXo410evr7t2fJP5eV4CYqa1m3FmpEIXunKPIe1gp+C8xd/8I5z07VPkPYVzm01Gbojj9AgMBAAEwDQYJKoZIhvcNAQELBQADggEBAEztS4CwEbXWh5Hu+FVBA5eiUP/YTA909MkK0v9O4txrt8tHIhUj/WvYtkuL6q44yaz+dWkDG3zHHo3RoSBBr4wTvbtsT4fwaEqylC4s+sQ+Z/wqASGxcuokO56S/ELL5dKJUtS+t/zLDpaMJSzWtBvKZvHMBwI6ubo4HMNI2yYO9YuPHgH6hjT05MBmX/XY1xbO00kr3cGn9dENGoRf5rlXiAFyxc5PDkYGjd6tv63p9pGpMvBvKMz27p7YR/MAe15Af4LxfkEofOORMG5G2jZLYMA7qZBmNY5waXjBxmaxx8vVbYhXzUzEoT/Ms6QN0k6WV6merAN/DFmi69H0njk='),
('97c87aa3-672b-4038-89fc-f31fa2cfc41c','46bc5eb2-0fb5-4955-8a0f-dfabaa48953e','priority','100'),
('980eb607-a322-4dbf-b3d6-5acd8965b973','473a4602-fa1d-487d-b062-ffad9346c6fc','allowed-protocol-mapper-types','oidc-usermodel-attribute-mapper'),
('98dabe21-15cd-4df4-a53d-d64cd93ff6a6','8a510298-9577-4984-a48e-286db607aecc','allowed-protocol-mapper-types','oidc-full-name-mapper'),
('99cea9d8-d980-4b2e-98bc-72aad21e1015','473a4602-fa1d-487d-b062-ffad9346c6fc','allowed-protocol-mapper-types','oidc-full-name-mapper'),
('9d519ddb-567d-45de-8705-cddb4a4dd162','46bc5eb2-0fb5-4955-8a0f-dfabaa48953e','kid','d2e58337-efe6-4402-8608-4a9f472c209b'),
('9d6243ff-5471-4f4c-9cbf-4512dd2d96b1','d46bc997-8cc2-45b8-875f-6dfc90dc6d29','keyUse','SIG'),
('9f23d1bb-de93-443b-9d72-382d19915fd8','2615bb3e-7652-412a-80fb-9d566aefff55','allowed-protocol-mapper-types','oidc-full-name-mapper'),
('a545bb0e-8e39-46c8-9db1-f298f9fcadc4','29e059a7-e37b-45e7-8bc2-41845993b53c','kid','03818607-60c5-4762-8b68-572bae20acb0'),
('a637deed-8bab-4412-b68f-1382755157bc','62f3fc4a-3a69-4707-912b-60848a196818','allowed-protocol-mapper-types','oidc-full-name-mapper'),
('ae0f1350-f07f-432b-89ad-da32eacbce76','46bc5eb2-0fb5-4955-8a0f-dfabaa48953e','secret','7gjhxJah_jzCWF0Y6tlHyQ'),
('b1ca7f55-09cc-4354-9647-81e66e082792','ff236f10-59e1-4d4c-9133-a9f1beec9833','kid','04fa364f-6b06-4ff2-8c31-0e24593de6ba'),
('b80d9278-2c6e-4a26-9aee-14d8247dda4b','473a4602-fa1d-487d-b062-ffad9346c6fc','allowed-protocol-mapper-types','oidc-address-mapper'),
('bccf1bc8-3b25-48ea-a76e-cc530e65ea10','62f3fc4a-3a69-4707-912b-60848a196818','allowed-protocol-mapper-types','oidc-usermodel-attribute-mapper'),
('bcedfecf-6891-4c97-95e1-84665d8f5dac','bd83a7b3-3a4b-4f2f-b089-9cc779b9dda2','host-sending-registration-request-must-match','true'),
('c4b2b1e2-6859-483c-9dee-4460be22a960','0a969c3e-dc44-4daf-84d7-2216b37e8c88','max-clients','200'),
('c5eb1a71-ca1d-450b-ad6f-7e24974e5927','473a4602-fa1d-487d-b062-ffad9346c6fc','allowed-protocol-mapper-types','saml-user-property-mapper'),
('ceb13c69-6598-4f0e-ad23-ffc521acd0d7','56b276b0-e444-416e-8647-342012790c61','priority','100'),
('ced22258-c53f-44ed-b147-2f2f11f4a412','27fdcb0e-f619-447c-b60a-d150586f71ce','allow-default-scopes','true'),
('cffed7ef-2be4-4ab3-bb17-63885b91e580','8a510298-9577-4984-a48e-286db607aecc','allowed-protocol-mapper-types','oidc-usermodel-attribute-mapper'),
('d6513962-ddde-406b-9e6c-9ea5b561c512','62f3fc4a-3a69-4707-912b-60848a196818','allowed-protocol-mapper-types','oidc-sha256-pairwise-sub-mapper'),
('d83fce62-4a72-4909-87e6-7a824a01c086','2615bb3e-7652-412a-80fb-9d566aefff55','allowed-protocol-mapper-types','saml-user-property-mapper'),
('d9d33324-fd9c-4497-9df2-2b06e23ede7b','ff236f10-59e1-4d4c-9133-a9f1beec9833','priority','100'),
('dc8129be-ac70-49e0-831e-3e6ac4bc5043','cbe7233f-b58f-47d4-9036-d6861a330756','allow-default-scopes','true'),
('dfed0089-6ea7-4911-b628-ca4c3edd64ac','754f8672-04e4-4e01-9ebe-dc4528c8ff2e','keyUse','ENC'),
('e58424e7-4a8f-4c66-8fd2-75bac39763ee','210c9923-7635-4f00-af9a-9581abcfcc7a','host-sending-registration-request-must-match','true'),
('e9dba674-f5f0-4080-bac1-caf50d07f32f','2615bb3e-7652-412a-80fb-9d566aefff55','allowed-protocol-mapper-types','oidc-usermodel-property-mapper'),
('eaa7be4b-0cf8-421b-a1cb-a28c0c2237e0','2615bb3e-7652-412a-80fb-9d566aefff55','allowed-protocol-mapper-types','oidc-usermodel-attribute-mapper'),
('ecadae25-94f7-4790-8731-bbe0a6a857ad','56b276b0-e444-416e-8647-342012790c61','algorithm','HS256'),
('f7289496-1a4e-4779-9a08-3aa3467450d8','2615bb3e-7652-412a-80fb-9d566aefff55','allowed-protocol-mapper-types','oidc-sha256-pairwise-sub-mapper'),
('fd695eb1-7a2e-4c11-873a-82fbf24add5a','8a510298-9577-4984-a48e-286db607aecc','allowed-protocol-mapper-types','saml-user-property-mapper');
/*!40000 ALTER TABLE `COMPONENT_CONFIG` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `COMPOSITE_ROLE`
--

DROP TABLE IF EXISTS `COMPOSITE_ROLE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `COMPOSITE_ROLE` (
  `COMPOSITE` varchar(36) NOT NULL,
  `CHILD_ROLE` varchar(36) NOT NULL,
  PRIMARY KEY (`COMPOSITE`,`CHILD_ROLE`),
  KEY `IDX_COMPOSITE` (`COMPOSITE`),
  KEY `IDX_COMPOSITE_CHILD` (`CHILD_ROLE`),
  CONSTRAINT `FK_A63WVEKFTU8JO1PNJ81E7MCE2` FOREIGN KEY (`COMPOSITE`) REFERENCES `KEYCLOAK_ROLE` (`ID`),
  CONSTRAINT `FK_GR7THLLB9LU8Q4VQA4524JJY8` FOREIGN KEY (`CHILD_ROLE`) REFERENCES `KEYCLOAK_ROLE` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `COMPOSITE_ROLE`
--

LOCK TABLES `COMPOSITE_ROLE` WRITE;
/*!40000 ALTER TABLE `COMPOSITE_ROLE` DISABLE KEYS */;
INSERT INTO `COMPOSITE_ROLE` VALUES
('04b9f1fa-05af-4d6e-84b2-5547bb07db93','47bbb3e1-292e-4030-9f0e-647adce5e895'),
('0c717c17-cbf2-431e-849b-ba3ab501c84e','c56c4e3d-54a0-4b8b-847b-3fd5b9ea064e'),
('32967061-2daa-4b03-9c98-fea124508e49','9b322368-4c64-4f00-a4d7-b58d79cc1114'),
('32967061-2daa-4b03-9c98-fea124508e49','c80996a8-0853-4048-9692-5f57c834d736'),
('40ecc019-54d6-439e-a3f6-248dee4348d7','e77cbf31-3f9f-4fd7-98d6-fb3874e3d333'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','0603741c-defd-49b1-9752-a653420278e4'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','0c717c17-cbf2-431e-849b-ba3ab501c84e'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','2ea0ff4e-e8ba-4b89-b905-90a253a52dc3'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','32967061-2daa-4b03-9c98-fea124508e49'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','40cfa785-fcdd-4b9c-bd00-3c087cbecb73'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','42792b2f-1030-439a-9649-f79abe962874'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','4565f2af-1a67-4a8c-ab81-1179809d2843'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','522675f9-101b-48dd-8bef-6ef49d5b08e7'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','5971d557-6a46-4205-ae47-477fddde62e6'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','7ae4cbaa-a874-4ca4-aa73-118fe92fd794'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','9b322368-4c64-4f00-a4d7-b58d79cc1114'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','a072e5cd-12e3-4c5d-8986-be785b879491'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','c56c4e3d-54a0-4b8b-847b-3fd5b9ea064e'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','c5d17a69-4e3d-4ecf-9ecb-22254222d892'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','c80996a8-0853-4048-9692-5f57c834d736'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','cd3b1dfe-1255-43f1-b432-969367725fd1'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','e56f9623-383d-4c1e-98bb-526c9a7ec2d0'),
('41469b32-8a9b-41c6-b95b-510f0b43be46','f0d7410e-c1b1-42c7-977e-eee8fe1cb287'),
('4a294e0d-7c96-4075-a877-939285371341','ed5e8c9f-eeab-4bbe-b7ea-600b583500e2'),
('4cf898aa-f789-41da-898f-189dcb198e9a','1bd065ea-b8b1-4c30-8f9d-811a635ebd21'),
('4cf898aa-f789-41da-898f-189dcb198e9a','7207c52d-ebc5-4c1b-8cf9-cdbc8d42e65c'),
('4cf898aa-f789-41da-898f-189dcb198e9a','cfce9bea-2fd5-40f2-8511-fb4d78b459b7'),
('4cf898aa-f789-41da-898f-189dcb198e9a','f4b3e6be-a3dd-42af-a25c-fdfabce36bc6'),
('58078af1-190f-4be7-898e-1483079764d5','fa9da988-b408-44bc-bc78-df4f5d75ff3d'),
('6d1173c8-2563-47c0-aafc-931b68643e16','60f686a3-e000-48e0-a117-0b4caf34843c'),
('6d1173c8-2563-47c0-aafc-931b68643e16','db342d6a-f694-4232-a1d2-c333a0f49d12'),
('7207c52d-ebc5-4c1b-8cf9-cdbc8d42e65c','3b072ba0-29ed-4177-91be-1c9423b1bdd6'),
('776be460-f860-4ad0-b180-3c34b82db253','4a6e36e1-951d-4b3a-9195-3a78abd1ddef'),
('776be460-f860-4ad0-b180-3c34b82db253','ee8156fa-bfe0-4d04-884e-a7eca3192655'),
('8ba12694-c3ad-4d6e-8ab8-d9244e711acf','a0f830a0-92b0-4d84-aaba-f19182ad9f5c'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','0e601c18-df7b-471a-9a87-4baf6a4dadbc'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','24015241-7cfc-4c80-89c4-c188ace09d04'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','2509be78-470d-45f3-8f0e-983a6b564820'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','310d6c65-d1e4-4f48-9147-9a3960a7eec1'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','367f6def-88d7-4ff8-94bf-e94a395ff5e9'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','39cb7bb4-e9f1-4a04-96ee-09b239f55189'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','40ecc019-54d6-439e-a3f6-248dee4348d7'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','4a294e0d-7c96-4075-a877-939285371341'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','4a6e36e1-951d-4b3a-9195-3a78abd1ddef'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','4b3020c2-09c2-45d0-a5ff-d608efd20ba2'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','5007bd80-5988-489e-9025-52a0a49e1e52'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','60f686a3-e000-48e0-a117-0b4caf34843c'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','6c1f7f0a-e3fe-462a-99d9-f700b094fd32'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','6d1173c8-2563-47c0-aafc-931b68643e16'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','776be460-f860-4ad0-b180-3c34b82db253'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','8669a10b-32ee-4240-bd68-5ec6f59a0aa9'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','8f95351c-cc02-4f96-b883-41b1b2feef8e'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','908cf046-58fc-48a1-b4a8-7aa424dd2f0d'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','92959480-9696-4b5d-87f2-787493801511'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','9bc29a79-b138-454c-b26a-1627f2b29d6e'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','a445a268-b8e3-4552-a988-71aac1920a08'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','a6f80cb2-e076-4d2b-9abe-e1303f66a0c8'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','a9909df8-475f-4b43-a561-3a0a3e378fe0'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','cc67f0fd-4e21-4f7b-8973-f5133e7eb14a'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','d689cb68-f4e8-4afd-a6aa-0bd055e25dab'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','d8dc70d8-b00d-43ac-a073-349423855750'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','d90ebcbb-b0e5-4a6d-880a-40e9b597dcdb'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','db342d6a-f694-4232-a1d2-c333a0f49d12'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','e3101047-075d-4185-b483-672411f16b2f'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','e43667c9-014c-499f-be0e-d975b0a79d10'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','e4bfe48b-9fbd-43f3-b839-aad767eb55c9'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','e527b9d3-a311-4f3e-a739-b18ec80b5072'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','e77cbf31-3f9f-4fd7-98d6-fb3874e3d333'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','ed5e8c9f-eeab-4bbe-b7ea-600b583500e2'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','ee8156fa-bfe0-4d04-884e-a7eca3192655'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','ee8d028f-3562-4f46-8ebe-f39cc3243aba'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','f2c4291c-8979-4cc5-a76d-75432e39b15b'),
('c689852f-3f23-4e75-93cb-dc268de0198b','04b9f1fa-05af-4d6e-84b2-5547bb07db93'),
('c689852f-3f23-4e75-93cb-dc268de0198b','82963599-c642-47d1-b310-58c6e81a9360'),
('c689852f-3f23-4e75-93cb-dc268de0198b','c16898f7-7206-4f7f-bc17-8cd0dead927b'),
('c689852f-3f23-4e75-93cb-dc268de0198b','df5f87a1-976d-47e6-bec8-00d241ccb192');
/*!40000 ALTER TABLE `COMPOSITE_ROLE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CREDENTIAL`
--

DROP TABLE IF EXISTS `CREDENTIAL`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CREDENTIAL` (
  `ID` varchar(36) NOT NULL,
  `SALT` tinyblob DEFAULT NULL,
  `TYPE` varchar(255) DEFAULT NULL,
  `USER_ID` varchar(36) DEFAULT NULL,
  `CREATED_DATE` bigint(20) DEFAULT NULL,
  `USER_LABEL` varchar(255) DEFAULT NULL,
  `SECRET_DATA` longtext DEFAULT NULL,
  `CREDENTIAL_DATA` longtext DEFAULT NULL,
  `PRIORITY` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_USER_CREDENTIAL` (`USER_ID`),
  CONSTRAINT `FK_PFYR0GLASQYL0DEI3KL69R6V0` FOREIGN KEY (`USER_ID`) REFERENCES `USER_ENTITY` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CREDENTIAL`
--

LOCK TABLES `CREDENTIAL` WRITE;
/*!40000 ALTER TABLE `CREDENTIAL` DISABLE KEYS */;
INSERT INTO `CREDENTIAL` VALUES
('ada154e2-3b1e-43d9-813a-e6b6d5e33801',NULL,'password','6a0aaa6e-460a-488c-ae61-f5703d03fa3b',1743396845738,NULL,'{\"value\":\"CLIti/GPRjFgxFh6enrKRGtbvIwDmi/pHZx5w4XzIvA=\",\"salt\":\"s/MUXsjzmWou6OURNypsAg==\",\"additionalParameters\":{}}','{\"hashIterations\":27500,\"algorithm\":\"pbkdf2-sha256\",\"additionalParameters\":{}}',10),
('b2aba192-05fc-4583-841f-d283c2d18a5b',NULL,'password','650758f6-3448-4985-a3d6-d925830b1cb5',1743396842206,NULL,'{\"value\":\"qrNWb7RSUfoRNadA1tq2HV7AFKLTqiDmZ+/8oRWvCEI=\",\"salt\":\"zNAWi2i4eZ1GqIADfLI1UQ==\",\"additionalParameters\":{}}','{\"hashIterations\":27500,\"algorithm\":\"pbkdf2-sha256\",\"additionalParameters\":{}}',10);
/*!40000 ALTER TABLE `CREDENTIAL` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `DATABASECHANGELOG`
--

DROP TABLE IF EXISTS `DATABASECHANGELOG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DATABASECHANGELOG` (
  `ID` varchar(255) NOT NULL,
  `AUTHOR` varchar(255) NOT NULL,
  `FILENAME` varchar(255) NOT NULL,
  `DATEEXECUTED` datetime NOT NULL,
  `ORDEREXECUTED` int(11) NOT NULL,
  `EXECTYPE` varchar(10) NOT NULL,
  `MD5SUM` varchar(35) DEFAULT NULL,
  `DESCRIPTION` varchar(255) DEFAULT NULL,
  `COMMENTS` varchar(255) DEFAULT NULL,
  `TAG` varchar(255) DEFAULT NULL,
  `LIQUIBASE` varchar(20) DEFAULT NULL,
  `CONTEXTS` varchar(255) DEFAULT NULL,
  `LABELS` varchar(255) DEFAULT NULL,
  `DEPLOYMENT_ID` varchar(10) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `DATABASECHANGELOG`
--

LOCK TABLES `DATABASECHANGELOG` WRITE;
/*!40000 ALTER TABLE `DATABASECHANGELOG` DISABLE KEYS */;
INSERT INTO `DATABASECHANGELOG` VALUES
('1.0.0.Final-KEYCLOAK-5461','sthorger@redhat.com','META-INF/jpa-changelog-1.0.0.Final.xml','2025-03-31 04:52:32',1,'EXECUTED','9:6f1016664e21e16d26517a4418f5e3df','createTable tableName=APPLICATION_DEFAULT_ROLES; createTable tableName=CLIENT; createTable tableName=CLIENT_SESSION; createTable tableName=CLIENT_SESSION_ROLE; createTable tableName=COMPOSITE_ROLE; createTable tableName=CREDENTIAL; createTable tab...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.0.0.Final-KEYCLOAK-5461','sthorger@redhat.com','META-INF/db2-jpa-changelog-1.0.0.Final.xml','2025-03-31 04:52:32',2,'MARK_RAN','9:828775b1596a07d1200ba1d49e5e3941','createTable tableName=APPLICATION_DEFAULT_ROLES; createTable tableName=CLIENT; createTable tableName=CLIENT_SESSION; createTable tableName=CLIENT_SESSION_ROLE; createTable tableName=COMPOSITE_ROLE; createTable tableName=CREDENTIAL; createTable tab...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.1.0.Beta1','sthorger@redhat.com','META-INF/jpa-changelog-1.1.0.Beta1.xml','2025-03-31 04:52:33',3,'EXECUTED','9:5f090e44a7d595883c1fb61f4b41fd38','delete tableName=CLIENT_SESSION_ROLE; delete tableName=CLIENT_SESSION; delete tableName=USER_SESSION; createTable tableName=CLIENT_ATTRIBUTES; createTable tableName=CLIENT_SESSION_NOTE; createTable tableName=APP_NODE_REGISTRATIONS; addColumn table...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.1.0.Final','sthorger@redhat.com','META-INF/jpa-changelog-1.1.0.Final.xml','2025-03-31 04:52:33',4,'EXECUTED','9:c07e577387a3d2c04d1adc9aaad8730e','renameColumn newColumnName=EVENT_TIME, oldColumnName=TIME, tableName=EVENT_ENTITY','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.2.0.Beta1','psilva@redhat.com','META-INF/jpa-changelog-1.2.0.Beta1.xml','2025-03-31 04:52:35',5,'EXECUTED','9:b68ce996c655922dbcd2fe6b6ae72686','delete tableName=CLIENT_SESSION_ROLE; delete tableName=CLIENT_SESSION_NOTE; delete tableName=CLIENT_SESSION; delete tableName=USER_SESSION; createTable tableName=PROTOCOL_MAPPER; createTable tableName=PROTOCOL_MAPPER_CONFIG; createTable tableName=...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.2.0.Beta1','psilva@redhat.com','META-INF/db2-jpa-changelog-1.2.0.Beta1.xml','2025-03-31 04:52:35',6,'MARK_RAN','9:543b5c9989f024fe35c6f6c5a97de88e','delete tableName=CLIENT_SESSION_ROLE; delete tableName=CLIENT_SESSION_NOTE; delete tableName=CLIENT_SESSION; delete tableName=USER_SESSION; createTable tableName=PROTOCOL_MAPPER; createTable tableName=PROTOCOL_MAPPER_CONFIG; createTable tableName=...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.2.0.RC1','bburke@redhat.com','META-INF/jpa-changelog-1.2.0.CR1.xml','2025-03-31 04:52:37',7,'EXECUTED','9:765afebbe21cf5bbca048e632df38336','delete tableName=CLIENT_SESSION_ROLE; delete tableName=CLIENT_SESSION_NOTE; delete tableName=CLIENT_SESSION; delete tableName=USER_SESSION_NOTE; delete tableName=USER_SESSION; createTable tableName=MIGRATION_MODEL; createTable tableName=IDENTITY_P...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.2.0.RC1','bburke@redhat.com','META-INF/db2-jpa-changelog-1.2.0.CR1.xml','2025-03-31 04:52:37',8,'MARK_RAN','9:db4a145ba11a6fdaefb397f6dbf829a1','delete tableName=CLIENT_SESSION_ROLE; delete tableName=CLIENT_SESSION_NOTE; delete tableName=CLIENT_SESSION; delete tableName=USER_SESSION_NOTE; delete tableName=USER_SESSION; createTable tableName=MIGRATION_MODEL; createTable tableName=IDENTITY_P...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.2.0.Final','keycloak','META-INF/jpa-changelog-1.2.0.Final.xml','2025-03-31 04:52:37',9,'EXECUTED','9:9d05c7be10cdb873f8bcb41bc3a8ab23','update tableName=CLIENT; update tableName=CLIENT; update tableName=CLIENT','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.3.0','bburke@redhat.com','META-INF/jpa-changelog-1.3.0.xml','2025-03-31 04:52:39',10,'EXECUTED','9:18593702353128d53111f9b1ff0b82b8','delete tableName=CLIENT_SESSION_ROLE; delete tableName=CLIENT_SESSION_PROT_MAPPER; delete tableName=CLIENT_SESSION_NOTE; delete tableName=CLIENT_SESSION; delete tableName=USER_SESSION_NOTE; delete tableName=USER_SESSION; createTable tableName=ADMI...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.4.0','bburke@redhat.com','META-INF/jpa-changelog-1.4.0.xml','2025-03-31 04:52:40',11,'EXECUTED','9:6122efe5f090e41a85c0f1c9e52cbb62','delete tableName=CLIENT_SESSION_AUTH_STATUS; delete tableName=CLIENT_SESSION_ROLE; delete tableName=CLIENT_SESSION_PROT_MAPPER; delete tableName=CLIENT_SESSION_NOTE; delete tableName=CLIENT_SESSION; delete tableName=USER_SESSION_NOTE; delete table...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.4.0','bburke@redhat.com','META-INF/db2-jpa-changelog-1.4.0.xml','2025-03-31 04:52:40',12,'MARK_RAN','9:e1ff28bf7568451453f844c5d54bb0b5','delete tableName=CLIENT_SESSION_AUTH_STATUS; delete tableName=CLIENT_SESSION_ROLE; delete tableName=CLIENT_SESSION_PROT_MAPPER; delete tableName=CLIENT_SESSION_NOTE; delete tableName=CLIENT_SESSION; delete tableName=USER_SESSION_NOTE; delete table...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.5.0','bburke@redhat.com','META-INF/jpa-changelog-1.5.0.xml','2025-03-31 04:52:40',13,'EXECUTED','9:7af32cd8957fbc069f796b61217483fd','delete tableName=CLIENT_SESSION_AUTH_STATUS; delete tableName=CLIENT_SESSION_ROLE; delete tableName=CLIENT_SESSION_PROT_MAPPER; delete tableName=CLIENT_SESSION_NOTE; delete tableName=CLIENT_SESSION; delete tableName=USER_SESSION_NOTE; delete table...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.6.1_from15','mposolda@redhat.com','META-INF/jpa-changelog-1.6.1.xml','2025-03-31 04:52:40',14,'EXECUTED','9:6005e15e84714cd83226bf7879f54190','addColumn tableName=REALM; addColumn tableName=KEYCLOAK_ROLE; addColumn tableName=CLIENT; createTable tableName=OFFLINE_USER_SESSION; createTable tableName=OFFLINE_CLIENT_SESSION; addPrimaryKey constraintName=CONSTRAINT_OFFL_US_SES_PK2, tableName=...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.6.1_from16-pre','mposolda@redhat.com','META-INF/jpa-changelog-1.6.1.xml','2025-03-31 04:52:40',15,'MARK_RAN','9:bf656f5a2b055d07f314431cae76f06c','delete tableName=OFFLINE_CLIENT_SESSION; delete tableName=OFFLINE_USER_SESSION','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.6.1_from16','mposolda@redhat.com','META-INF/jpa-changelog-1.6.1.xml','2025-03-31 04:52:40',16,'MARK_RAN','9:f8dadc9284440469dcf71e25ca6ab99b','dropPrimaryKey constraintName=CONSTRAINT_OFFLINE_US_SES_PK, tableName=OFFLINE_USER_SESSION; dropPrimaryKey constraintName=CONSTRAINT_OFFLINE_CL_SES_PK, tableName=OFFLINE_CLIENT_SESSION; addColumn tableName=OFFLINE_USER_SESSION; update tableName=OF...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.6.1','mposolda@redhat.com','META-INF/jpa-changelog-1.6.1.xml','2025-03-31 04:52:40',17,'EXECUTED','9:d41d8cd98f00b204e9800998ecf8427e','empty','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.7.0','bburke@redhat.com','META-INF/jpa-changelog-1.7.0.xml','2025-03-31 04:52:42',18,'EXECUTED','9:3368ff0be4c2855ee2dd9ca813b38d8e','createTable tableName=KEYCLOAK_GROUP; createTable tableName=GROUP_ROLE_MAPPING; createTable tableName=GROUP_ATTRIBUTE; createTable tableName=USER_GROUP_MEMBERSHIP; createTable tableName=REALM_DEFAULT_GROUPS; addColumn tableName=IDENTITY_PROVIDER; ...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.8.0','mposolda@redhat.com','META-INF/jpa-changelog-1.8.0.xml','2025-03-31 04:52:43',19,'EXECUTED','9:8ac2fb5dd030b24c0570a763ed75ed20','addColumn tableName=IDENTITY_PROVIDER; createTable tableName=CLIENT_TEMPLATE; createTable tableName=CLIENT_TEMPLATE_ATTRIBUTES; createTable tableName=TEMPLATE_SCOPE_MAPPING; dropNotNullConstraint columnName=CLIENT_ID, tableName=PROTOCOL_MAPPER; ad...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.8.0-2','keycloak','META-INF/jpa-changelog-1.8.0.xml','2025-03-31 04:52:43',20,'EXECUTED','9:f91ddca9b19743db60e3057679810e6c','dropDefaultValue columnName=ALGORITHM, tableName=CREDENTIAL; update tableName=CREDENTIAL','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.8.0','mposolda@redhat.com','META-INF/db2-jpa-changelog-1.8.0.xml','2025-03-31 04:52:43',21,'MARK_RAN','9:831e82914316dc8a57dc09d755f23c51','addColumn tableName=IDENTITY_PROVIDER; createTable tableName=CLIENT_TEMPLATE; createTable tableName=CLIENT_TEMPLATE_ATTRIBUTES; createTable tableName=TEMPLATE_SCOPE_MAPPING; dropNotNullConstraint columnName=CLIENT_ID, tableName=PROTOCOL_MAPPER; ad...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.8.0-2','keycloak','META-INF/db2-jpa-changelog-1.8.0.xml','2025-03-31 04:52:43',22,'MARK_RAN','9:f91ddca9b19743db60e3057679810e6c','dropDefaultValue columnName=ALGORITHM, tableName=CREDENTIAL; update tableName=CREDENTIAL','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.9.0','mposolda@redhat.com','META-INF/jpa-changelog-1.9.0.xml','2025-03-31 04:52:43',23,'EXECUTED','9:bc3d0f9e823a69dc21e23e94c7a94bb1','update tableName=REALM; update tableName=REALM; update tableName=REALM; update tableName=REALM; update tableName=CREDENTIAL; update tableName=CREDENTIAL; update tableName=CREDENTIAL; update tableName=REALM; update tableName=REALM; customChange; dr...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.9.1','keycloak','META-INF/jpa-changelog-1.9.1.xml','2025-03-31 04:52:43',24,'EXECUTED','9:c9999da42f543575ab790e76439a2679','modifyDataType columnName=PRIVATE_KEY, tableName=REALM; modifyDataType columnName=PUBLIC_KEY, tableName=REALM; modifyDataType columnName=CERTIFICATE, tableName=REALM','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.9.1','keycloak','META-INF/db2-jpa-changelog-1.9.1.xml','2025-03-31 04:52:43',25,'MARK_RAN','9:0d6c65c6f58732d81569e77b10ba301d','modifyDataType columnName=PRIVATE_KEY, tableName=REALM; modifyDataType columnName=CERTIFICATE, tableName=REALM','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('1.9.2','keycloak','META-INF/jpa-changelog-1.9.2.xml','2025-03-31 04:52:44',26,'EXECUTED','9:fc576660fc016ae53d2d4778d84d86d0','createIndex indexName=IDX_USER_EMAIL, tableName=USER_ENTITY; createIndex indexName=IDX_USER_ROLE_MAPPING, tableName=USER_ROLE_MAPPING; createIndex indexName=IDX_USER_GROUP_MAPPING, tableName=USER_GROUP_MEMBERSHIP; createIndex indexName=IDX_USER_CO...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authz-2.0.0','psilva@redhat.com','META-INF/jpa-changelog-authz-2.0.0.xml','2025-03-31 04:52:46',27,'EXECUTED','9:43ed6b0da89ff77206289e87eaa9c024','createTable tableName=RESOURCE_SERVER; addPrimaryKey constraintName=CONSTRAINT_FARS, tableName=RESOURCE_SERVER; addUniqueConstraint constraintName=UK_AU8TT6T700S9V50BU18WS5HA6, tableName=RESOURCE_SERVER; createTable tableName=RESOURCE_SERVER_RESOU...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authz-2.5.1','psilva@redhat.com','META-INF/jpa-changelog-authz-2.5.1.xml','2025-03-31 04:52:46',28,'EXECUTED','9:44bae577f551b3738740281eceb4ea70','update tableName=RESOURCE_SERVER_POLICY','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('2.1.0-KEYCLOAK-5461','bburke@redhat.com','META-INF/jpa-changelog-2.1.0.xml','2025-03-31 04:52:47',29,'EXECUTED','9:bd88e1f833df0420b01e114533aee5e8','createTable tableName=BROKER_LINK; createTable tableName=FED_USER_ATTRIBUTE; createTable tableName=FED_USER_CONSENT; createTable tableName=FED_USER_CONSENT_ROLE; createTable tableName=FED_USER_CONSENT_PROT_MAPPER; createTable tableName=FED_USER_CR...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('2.2.0','bburke@redhat.com','META-INF/jpa-changelog-2.2.0.xml','2025-03-31 04:52:47',30,'EXECUTED','9:a7022af5267f019d020edfe316ef4371','addColumn tableName=ADMIN_EVENT_ENTITY; createTable tableName=CREDENTIAL_ATTRIBUTE; createTable tableName=FED_CREDENTIAL_ATTRIBUTE; modifyDataType columnName=VALUE, tableName=CREDENTIAL; addForeignKeyConstraint baseTableName=FED_CREDENTIAL_ATTRIBU...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('2.3.0','bburke@redhat.com','META-INF/jpa-changelog-2.3.0.xml','2025-03-31 04:52:47',31,'EXECUTED','9:fc155c394040654d6a79227e56f5e25a','createTable tableName=FEDERATED_USER; addPrimaryKey constraintName=CONSTR_FEDERATED_USER, tableName=FEDERATED_USER; dropDefaultValue columnName=TOTP, tableName=USER_ENTITY; dropColumn columnName=TOTP, tableName=USER_ENTITY; addColumn tableName=IDE...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('2.4.0','bburke@redhat.com','META-INF/jpa-changelog-2.4.0.xml','2025-03-31 04:52:47',32,'EXECUTED','9:eac4ffb2a14795e5dc7b426063e54d88','customChange','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('2.5.0','bburke@redhat.com','META-INF/jpa-changelog-2.5.0.xml','2025-03-31 04:52:48',33,'EXECUTED','9:54937c05672568c4c64fc9524c1e9462','customChange; modifyDataType columnName=USER_ID, tableName=OFFLINE_USER_SESSION','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('2.5.0-unicode-oracle','hmlnarik@redhat.com','META-INF/jpa-changelog-2.5.0.xml','2025-03-31 04:52:48',34,'MARK_RAN','9:3a32bace77c84d7678d035a7f5a8084e','modifyDataType columnName=DESCRIPTION, tableName=AUTHENTICATION_FLOW; modifyDataType columnName=DESCRIPTION, tableName=CLIENT_TEMPLATE; modifyDataType columnName=DESCRIPTION, tableName=RESOURCE_SERVER_POLICY; modifyDataType columnName=DESCRIPTION,...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('2.5.0-unicode-other-dbs','hmlnarik@redhat.com','META-INF/jpa-changelog-2.5.0.xml','2025-03-31 04:52:50',35,'EXECUTED','9:33d72168746f81f98ae3a1e8e0ca3554','modifyDataType columnName=DESCRIPTION, tableName=AUTHENTICATION_FLOW; modifyDataType columnName=DESCRIPTION, tableName=CLIENT_TEMPLATE; modifyDataType columnName=DESCRIPTION, tableName=RESOURCE_SERVER_POLICY; modifyDataType columnName=DESCRIPTION,...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('2.5.0-duplicate-email-support','slawomir@dabek.name','META-INF/jpa-changelog-2.5.0.xml','2025-03-31 04:52:50',36,'EXECUTED','9:61b6d3d7a4c0e0024b0c839da283da0c','addColumn tableName=REALM','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('2.5.0-unique-group-names','hmlnarik@redhat.com','META-INF/jpa-changelog-2.5.0.xml','2025-03-31 04:52:50',37,'EXECUTED','9:8dcac7bdf7378e7d823cdfddebf72fda','addUniqueConstraint constraintName=SIBLING_NAMES, tableName=KEYCLOAK_GROUP','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('2.5.1','bburke@redhat.com','META-INF/jpa-changelog-2.5.1.xml','2025-03-31 04:52:50',38,'EXECUTED','9:a2b870802540cb3faa72098db5388af3','addColumn tableName=FED_USER_CONSENT','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('3.0.0','bburke@redhat.com','META-INF/jpa-changelog-3.0.0.xml','2025-03-31 04:52:50',39,'EXECUTED','9:132a67499ba24bcc54fb5cbdcfe7e4c0','addColumn tableName=IDENTITY_PROVIDER','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('3.2.0-fix','keycloak','META-INF/jpa-changelog-3.2.0.xml','2025-03-31 04:52:50',40,'MARK_RAN','9:938f894c032f5430f2b0fafb1a243462','addNotNullConstraint columnName=REALM_ID, tableName=CLIENT_INITIAL_ACCESS','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('3.2.0-fix-with-keycloak-5416','keycloak','META-INF/jpa-changelog-3.2.0.xml','2025-03-31 04:52:50',41,'MARK_RAN','9:845c332ff1874dc5d35974b0babf3006','dropIndex indexName=IDX_CLIENT_INIT_ACC_REALM, tableName=CLIENT_INITIAL_ACCESS; addNotNullConstraint columnName=REALM_ID, tableName=CLIENT_INITIAL_ACCESS; createIndex indexName=IDX_CLIENT_INIT_ACC_REALM, tableName=CLIENT_INITIAL_ACCESS','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('3.2.0-fix-offline-sessions','hmlnarik','META-INF/jpa-changelog-3.2.0.xml','2025-03-31 04:52:50',42,'EXECUTED','9:fc86359c079781adc577c5a217e4d04c','customChange','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('3.2.0-fixed','keycloak','META-INF/jpa-changelog-3.2.0.xml','2025-03-31 04:52:54',43,'EXECUTED','9:59a64800e3c0d09b825f8a3b444fa8f4','addColumn tableName=REALM; dropPrimaryKey constraintName=CONSTRAINT_OFFL_CL_SES_PK2, tableName=OFFLINE_CLIENT_SESSION; dropColumn columnName=CLIENT_SESSION_ID, tableName=OFFLINE_CLIENT_SESSION; addPrimaryKey constraintName=CONSTRAINT_OFFL_CL_SES_P...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('3.3.0','keycloak','META-INF/jpa-changelog-3.3.0.xml','2025-03-31 04:52:55',44,'EXECUTED','9:d48d6da5c6ccf667807f633fe489ce88','addColumn tableName=USER_ENTITY','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authz-3.4.0.CR1-resource-server-pk-change-part1','glavoie@gmail.com','META-INF/jpa-changelog-authz-3.4.0.CR1.xml','2025-03-31 04:52:55',45,'EXECUTED','9:dde36f7973e80d71fceee683bc5d2951','addColumn tableName=RESOURCE_SERVER_POLICY; addColumn tableName=RESOURCE_SERVER_RESOURCE; addColumn tableName=RESOURCE_SERVER_SCOPE','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authz-3.4.0.CR1-resource-server-pk-change-part2-KEYCLOAK-6095','hmlnarik@redhat.com','META-INF/jpa-changelog-authz-3.4.0.CR1.xml','2025-03-31 04:52:55',46,'EXECUTED','9:b855e9b0a406b34fa323235a0cf4f640','customChange','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authz-3.4.0.CR1-resource-server-pk-change-part3-fixed','glavoie@gmail.com','META-INF/jpa-changelog-authz-3.4.0.CR1.xml','2025-03-31 04:52:55',47,'MARK_RAN','9:51abbacd7b416c50c4421a8cabf7927e','dropIndex indexName=IDX_RES_SERV_POL_RES_SERV, tableName=RESOURCE_SERVER_POLICY; dropIndex indexName=IDX_RES_SRV_RES_RES_SRV, tableName=RESOURCE_SERVER_RESOURCE; dropIndex indexName=IDX_RES_SRV_SCOPE_RES_SRV, tableName=RESOURCE_SERVER_SCOPE','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authz-3.4.0.CR1-resource-server-pk-change-part3-fixed-nodropindex','glavoie@gmail.com','META-INF/jpa-changelog-authz-3.4.0.CR1.xml','2025-03-31 04:52:57',48,'EXECUTED','9:bdc99e567b3398bac83263d375aad143','addNotNullConstraint columnName=RESOURCE_SERVER_CLIENT_ID, tableName=RESOURCE_SERVER_POLICY; addNotNullConstraint columnName=RESOURCE_SERVER_CLIENT_ID, tableName=RESOURCE_SERVER_RESOURCE; addNotNullConstraint columnName=RESOURCE_SERVER_CLIENT_ID, ...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authn-3.4.0.CR1-refresh-token-max-reuse','glavoie@gmail.com','META-INF/jpa-changelog-authz-3.4.0.CR1.xml','2025-03-31 04:52:57',49,'EXECUTED','9:d198654156881c46bfba39abd7769e69','addColumn tableName=REALM','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('3.4.0','keycloak','META-INF/jpa-changelog-3.4.0.xml','2025-03-31 04:53:00',50,'EXECUTED','9:cfdd8736332ccdd72c5256ccb42335db','addPrimaryKey constraintName=CONSTRAINT_REALM_DEFAULT_ROLES, tableName=REALM_DEFAULT_ROLES; addPrimaryKey constraintName=CONSTRAINT_COMPOSITE_ROLE, tableName=COMPOSITE_ROLE; addPrimaryKey constraintName=CONSTR_REALM_DEFAULT_GROUPS, tableName=REALM...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('3.4.0-KEYCLOAK-5230','hmlnarik@redhat.com','META-INF/jpa-changelog-3.4.0.xml','2025-03-31 04:53:02',51,'EXECUTED','9:7c84de3d9bd84d7f077607c1a4dcb714','createIndex indexName=IDX_FU_ATTRIBUTE, tableName=FED_USER_ATTRIBUTE; createIndex indexName=IDX_FU_CONSENT, tableName=FED_USER_CONSENT; createIndex indexName=IDX_FU_CONSENT_RU, tableName=FED_USER_CONSENT; createIndex indexName=IDX_FU_CREDENTIAL, t...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('3.4.1','psilva@redhat.com','META-INF/jpa-changelog-3.4.1.xml','2025-03-31 04:53:02',52,'EXECUTED','9:5a6bb36cbefb6a9d6928452c0852af2d','modifyDataType columnName=VALUE, tableName=CLIENT_ATTRIBUTES','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('3.4.2','keycloak','META-INF/jpa-changelog-3.4.2.xml','2025-03-31 04:53:02',53,'EXECUTED','9:8f23e334dbc59f82e0a328373ca6ced0','update tableName=REALM','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('3.4.2-KEYCLOAK-5172','mkanis@redhat.com','META-INF/jpa-changelog-3.4.2.xml','2025-03-31 04:53:02',54,'EXECUTED','9:9156214268f09d970cdf0e1564d866af','update tableName=CLIENT','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.0.0-KEYCLOAK-6335','bburke@redhat.com','META-INF/jpa-changelog-4.0.0.xml','2025-03-31 04:53:02',55,'EXECUTED','9:db806613b1ed154826c02610b7dbdf74','createTable tableName=CLIENT_AUTH_FLOW_BINDINGS; addPrimaryKey constraintName=C_CLI_FLOW_BIND, tableName=CLIENT_AUTH_FLOW_BINDINGS','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.0.0-CLEANUP-UNUSED-TABLE','bburke@redhat.com','META-INF/jpa-changelog-4.0.0.xml','2025-03-31 04:53:03',56,'EXECUTED','9:229a041fb72d5beac76bb94a5fa709de','dropTable tableName=CLIENT_IDENTITY_PROV_MAPPING','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.0.0-KEYCLOAK-6228','bburke@redhat.com','META-INF/jpa-changelog-4.0.0.xml','2025-03-31 04:53:04',57,'EXECUTED','9:079899dade9c1e683f26b2aa9ca6ff04','dropUniqueConstraint constraintName=UK_JKUWUVD56ONTGSUHOGM8UEWRT, tableName=USER_CONSENT; dropNotNullConstraint columnName=CLIENT_ID, tableName=USER_CONSENT; addColumn tableName=USER_CONSENT; addUniqueConstraint constraintName=UK_JKUWUVD56ONTGSUHO...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.0.0-KEYCLOAK-5579-fixed','mposolda@redhat.com','META-INF/jpa-changelog-4.0.0.xml','2025-03-31 04:53:12',58,'EXECUTED','9:139b79bcbbfe903bb1c2d2a4dbf001d9','dropForeignKeyConstraint baseTableName=CLIENT_TEMPLATE_ATTRIBUTES, constraintName=FK_CL_TEMPL_ATTR_TEMPL; renameTable newTableName=CLIENT_SCOPE_ATTRIBUTES, oldTableName=CLIENT_TEMPLATE_ATTRIBUTES; renameColumn newColumnName=SCOPE_ID, oldColumnName...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authz-4.0.0.CR1','psilva@redhat.com','META-INF/jpa-changelog-authz-4.0.0.CR1.xml','2025-03-31 04:53:14',59,'EXECUTED','9:b55738ad889860c625ba2bf483495a04','createTable tableName=RESOURCE_SERVER_PERM_TICKET; addPrimaryKey constraintName=CONSTRAINT_FAPMT, tableName=RESOURCE_SERVER_PERM_TICKET; addForeignKeyConstraint baseTableName=RESOURCE_SERVER_PERM_TICKET, constraintName=FK_FRSRHO213XCX4WNKOG82SSPMT...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authz-4.0.0.Beta3','psilva@redhat.com','META-INF/jpa-changelog-authz-4.0.0.Beta3.xml','2025-03-31 04:53:14',60,'EXECUTED','9:e0057eac39aa8fc8e09ac6cfa4ae15fe','addColumn tableName=RESOURCE_SERVER_POLICY; addColumn tableName=RESOURCE_SERVER_PERM_TICKET; addForeignKeyConstraint baseTableName=RESOURCE_SERVER_PERM_TICKET, constraintName=FK_FRSRPO2128CX4WNKOG82SSRFY, referencedTableName=RESOURCE_SERVER_POLICY','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authz-4.2.0.Final','mhajas@redhat.com','META-INF/jpa-changelog-authz-4.2.0.Final.xml','2025-03-31 04:53:14',61,'EXECUTED','9:42a33806f3a0443fe0e7feeec821326c','createTable tableName=RESOURCE_URIS; addForeignKeyConstraint baseTableName=RESOURCE_URIS, constraintName=FK_RESOURCE_SERVER_URIS, referencedTableName=RESOURCE_SERVER_RESOURCE; customChange; dropColumn columnName=URI, tableName=RESOURCE_SERVER_RESO...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authz-4.2.0.Final-KEYCLOAK-9944','hmlnarik@redhat.com','META-INF/jpa-changelog-authz-4.2.0.Final.xml','2025-03-31 04:53:14',62,'EXECUTED','9:9968206fca46eecc1f51db9c024bfe56','addPrimaryKey constraintName=CONSTRAINT_RESOUR_URIS_PK, tableName=RESOURCE_URIS','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.2.0-KEYCLOAK-6313','wadahiro@gmail.com','META-INF/jpa-changelog-4.2.0.xml','2025-03-31 04:53:15',63,'EXECUTED','9:92143a6daea0a3f3b8f598c97ce55c3d','addColumn tableName=REQUIRED_ACTION_PROVIDER','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.3.0-KEYCLOAK-7984','wadahiro@gmail.com','META-INF/jpa-changelog-4.3.0.xml','2025-03-31 04:53:15',64,'EXECUTED','9:82bab26a27195d889fb0429003b18f40','update tableName=REQUIRED_ACTION_PROVIDER','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.6.0-KEYCLOAK-7950','psilva@redhat.com','META-INF/jpa-changelog-4.6.0.xml','2025-03-31 04:53:15',65,'EXECUTED','9:e590c88ddc0b38b0ae4249bbfcb5abc3','update tableName=RESOURCE_SERVER_RESOURCE','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.6.0-KEYCLOAK-8377','keycloak','META-INF/jpa-changelog-4.6.0.xml','2025-03-31 04:53:15',66,'EXECUTED','9:5c1f475536118dbdc38d5d7977950cc0','createTable tableName=ROLE_ATTRIBUTE; addPrimaryKey constraintName=CONSTRAINT_ROLE_ATTRIBUTE_PK, tableName=ROLE_ATTRIBUTE; addForeignKeyConstraint baseTableName=ROLE_ATTRIBUTE, constraintName=FK_ROLE_ATTRIBUTE_ID, referencedTableName=KEYCLOAK_ROLE...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.6.0-KEYCLOAK-8555','gideonray@gmail.com','META-INF/jpa-changelog-4.6.0.xml','2025-03-31 04:53:15',67,'EXECUTED','9:e7c9f5f9c4d67ccbbcc215440c718a17','createIndex indexName=IDX_COMPONENT_PROVIDER_TYPE, tableName=COMPONENT','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.7.0-KEYCLOAK-1267','sguilhen@redhat.com','META-INF/jpa-changelog-4.7.0.xml','2025-03-31 04:53:15',68,'EXECUTED','9:88e0bfdda924690d6f4e430c53447dd5','addColumn tableName=REALM','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.7.0-KEYCLOAK-7275','keycloak','META-INF/jpa-changelog-4.7.0.xml','2025-03-31 04:53:15',69,'EXECUTED','9:f53177f137e1c46b6a88c59ec1cb5218','renameColumn newColumnName=CREATED_ON, oldColumnName=LAST_SESSION_REFRESH, tableName=OFFLINE_USER_SESSION; addNotNullConstraint columnName=CREATED_ON, tableName=OFFLINE_USER_SESSION; addColumn tableName=OFFLINE_USER_SESSION; customChange; createIn...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('4.8.0-KEYCLOAK-8835','sguilhen@redhat.com','META-INF/jpa-changelog-4.8.0.xml','2025-03-31 04:53:15',70,'EXECUTED','9:a74d33da4dc42a37ec27121580d1459f','addNotNullConstraint columnName=SSO_MAX_LIFESPAN_REMEMBER_ME, tableName=REALM; addNotNullConstraint columnName=SSO_IDLE_TIMEOUT_REMEMBER_ME, tableName=REALM','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('authz-7.0.0-KEYCLOAK-10443','psilva@redhat.com','META-INF/jpa-changelog-authz-7.0.0.xml','2025-03-31 04:53:16',71,'EXECUTED','9:fd4ade7b90c3b67fae0bfcfcb42dfb5f','addColumn tableName=RESOURCE_SERVER','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('8.0.0-adding-credential-columns','keycloak','META-INF/jpa-changelog-8.0.0.xml','2025-03-31 04:53:16',72,'EXECUTED','9:aa072ad090bbba210d8f18781b8cebf4','addColumn tableName=CREDENTIAL; addColumn tableName=FED_USER_CREDENTIAL','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('8.0.0-updating-credential-data-not-oracle-fixed','keycloak','META-INF/jpa-changelog-8.0.0.xml','2025-03-31 04:53:16',73,'EXECUTED','9:1ae6be29bab7c2aa376f6983b932be37','update tableName=CREDENTIAL; update tableName=CREDENTIAL; update tableName=CREDENTIAL; update tableName=FED_USER_CREDENTIAL; update tableName=FED_USER_CREDENTIAL; update tableName=FED_USER_CREDENTIAL','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('8.0.0-updating-credential-data-oracle-fixed','keycloak','META-INF/jpa-changelog-8.0.0.xml','2025-03-31 04:53:16',74,'MARK_RAN','9:14706f286953fc9a25286dbd8fb30d97','update tableName=CREDENTIAL; update tableName=CREDENTIAL; update tableName=CREDENTIAL; update tableName=FED_USER_CREDENTIAL; update tableName=FED_USER_CREDENTIAL; update tableName=FED_USER_CREDENTIAL','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('8.0.0-credential-cleanup-fixed','keycloak','META-INF/jpa-changelog-8.0.0.xml','2025-03-31 04:53:17',75,'EXECUTED','9:2b9cc12779be32c5b40e2e67711a218b','dropDefaultValue columnName=COUNTER, tableName=CREDENTIAL; dropDefaultValue columnName=DIGITS, tableName=CREDENTIAL; dropDefaultValue columnName=PERIOD, tableName=CREDENTIAL; dropDefaultValue columnName=ALGORITHM, tableName=CREDENTIAL; dropColumn ...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('8.0.0-resource-tag-support','keycloak','META-INF/jpa-changelog-8.0.0.xml','2025-03-31 04:53:17',76,'EXECUTED','9:91fa186ce7a5af127a2d7a91ee083cc5','addColumn tableName=MIGRATION_MODEL; createIndex indexName=IDX_UPDATE_TIME, tableName=MIGRATION_MODEL','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('9.0.0-always-display-client','keycloak','META-INF/jpa-changelog-9.0.0.xml','2025-03-31 04:53:18',77,'EXECUTED','9:6335e5c94e83a2639ccd68dd24e2e5ad','addColumn tableName=CLIENT','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('9.0.0-drop-constraints-for-column-increase','keycloak','META-INF/jpa-changelog-9.0.0.xml','2025-03-31 04:53:18',78,'MARK_RAN','9:6bdb5658951e028bfe16fa0a8228b530','dropUniqueConstraint constraintName=UK_FRSR6T700S9V50BU18WS5PMT, tableName=RESOURCE_SERVER_PERM_TICKET; dropUniqueConstraint constraintName=UK_FRSR6T700S9V50BU18WS5HA6, tableName=RESOURCE_SERVER_RESOURCE; dropPrimaryKey constraintName=CONSTRAINT_O...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('9.0.0-increase-column-size-federated-fk','keycloak','META-INF/jpa-changelog-9.0.0.xml','2025-03-31 04:53:19',79,'EXECUTED','9:d5bc15a64117ccad481ce8792d4c608f','modifyDataType columnName=CLIENT_ID, tableName=FED_USER_CONSENT; modifyDataType columnName=CLIENT_REALM_CONSTRAINT, tableName=KEYCLOAK_ROLE; modifyDataType columnName=OWNER, tableName=RESOURCE_SERVER_POLICY; modifyDataType columnName=CLIENT_ID, ta...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('9.0.0-recreate-constraints-after-column-increase','keycloak','META-INF/jpa-changelog-9.0.0.xml','2025-03-31 04:53:19',80,'MARK_RAN','9:077cba51999515f4d3e7ad5619ab592c','addNotNullConstraint columnName=CLIENT_ID, tableName=OFFLINE_CLIENT_SESSION; addNotNullConstraint columnName=OWNER, tableName=RESOURCE_SERVER_PERM_TICKET; addNotNullConstraint columnName=REQUESTER, tableName=RESOURCE_SERVER_PERM_TICKET; addNotNull...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('9.0.1-add-index-to-client.client_id','keycloak','META-INF/jpa-changelog-9.0.1.xml','2025-03-31 04:53:19',81,'EXECUTED','9:be969f08a163bf47c6b9e9ead8ac2afb','createIndex indexName=IDX_CLIENT_ID, tableName=CLIENT','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('9.0.1-KEYCLOAK-12579-drop-constraints','keycloak','META-INF/jpa-changelog-9.0.1.xml','2025-03-31 04:53:19',82,'MARK_RAN','9:6d3bb4408ba5a72f39bd8a0b301ec6e3','dropUniqueConstraint constraintName=SIBLING_NAMES, tableName=KEYCLOAK_GROUP','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('9.0.1-KEYCLOAK-12579-add-not-null-constraint','keycloak','META-INF/jpa-changelog-9.0.1.xml','2025-03-31 04:53:19',83,'EXECUTED','9:966bda61e46bebf3cc39518fbed52fa7','addNotNullConstraint columnName=PARENT_GROUP, tableName=KEYCLOAK_GROUP','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('9.0.1-KEYCLOAK-12579-recreate-constraints','keycloak','META-INF/jpa-changelog-9.0.1.xml','2025-03-31 04:53:19',84,'MARK_RAN','9:8dcac7bdf7378e7d823cdfddebf72fda','addUniqueConstraint constraintName=SIBLING_NAMES, tableName=KEYCLOAK_GROUP','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('9.0.1-add-index-to-events','keycloak','META-INF/jpa-changelog-9.0.1.xml','2025-03-31 04:53:19',85,'EXECUTED','9:7d93d602352a30c0c317e6a609b56599','createIndex indexName=IDX_EVENT_TIME, tableName=EVENT_ENTITY','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('map-remove-ri','keycloak','META-INF/jpa-changelog-11.0.0.xml','2025-03-31 04:53:19',86,'EXECUTED','9:71c5969e6cdd8d7b6f47cebc86d37627','dropForeignKeyConstraint baseTableName=REALM, constraintName=FK_TRAF444KK6QRKMS7N56AIWQ5Y; dropForeignKeyConstraint baseTableName=KEYCLOAK_ROLE, constraintName=FK_KJHO5LE2C0RAL09FL8CM9WFW9','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('map-remove-ri','keycloak','META-INF/jpa-changelog-12.0.0.xml','2025-03-31 04:53:20',87,'EXECUTED','9:a9ba7d47f065f041b7da856a81762021','dropForeignKeyConstraint baseTableName=REALM_DEFAULT_GROUPS, constraintName=FK_DEF_GROUPS_GROUP; dropForeignKeyConstraint baseTableName=REALM_DEFAULT_ROLES, constraintName=FK_H4WPD7W4HSOOLNI3H0SW7BTJE; dropForeignKeyConstraint baseTableName=CLIENT...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('12.1.0-add-realm-localization-table','keycloak','META-INF/jpa-changelog-12.0.0.xml','2025-03-31 04:53:20',88,'EXECUTED','9:fffabce2bc01e1a8f5110d5278500065','createTable tableName=REALM_LOCALIZATIONS; addPrimaryKey tableName=REALM_LOCALIZATIONS','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('default-roles','keycloak','META-INF/jpa-changelog-13.0.0.xml','2025-03-31 04:53:20',89,'EXECUTED','9:fa8a5b5445e3857f4b010bafb5009957','addColumn tableName=REALM; customChange','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('default-roles-cleanup','keycloak','META-INF/jpa-changelog-13.0.0.xml','2025-03-31 04:53:20',90,'EXECUTED','9:67ac3241df9a8582d591c5ed87125f39','dropTable tableName=REALM_DEFAULT_ROLES; dropTable tableName=CLIENT_DEFAULT_ROLES','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('13.0.0-KEYCLOAK-16844','keycloak','META-INF/jpa-changelog-13.0.0.xml','2025-03-31 04:53:20',91,'EXECUTED','9:ad1194d66c937e3ffc82386c050ba089','createIndex indexName=IDX_OFFLINE_USS_PRELOAD, tableName=OFFLINE_USER_SESSION','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('map-remove-ri-13.0.0','keycloak','META-INF/jpa-changelog-13.0.0.xml','2025-03-31 04:53:20',92,'EXECUTED','9:d9be619d94af5a2f5d07b9f003543b91','dropForeignKeyConstraint baseTableName=DEFAULT_CLIENT_SCOPE, constraintName=FK_R_DEF_CLI_SCOPE_SCOPE; dropForeignKeyConstraint baseTableName=CLIENT_SCOPE_CLIENT, constraintName=FK_C_CLI_SCOPE_SCOPE; dropForeignKeyConstraint baseTableName=CLIENT_SC...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('13.0.0-KEYCLOAK-17992-drop-constraints','keycloak','META-INF/jpa-changelog-13.0.0.xml','2025-03-31 04:53:20',93,'MARK_RAN','9:544d201116a0fcc5a5da0925fbbc3bde','dropPrimaryKey constraintName=C_CLI_SCOPE_BIND, tableName=CLIENT_SCOPE_CLIENT; dropIndex indexName=IDX_CLSCOPE_CL, tableName=CLIENT_SCOPE_CLIENT; dropIndex indexName=IDX_CL_CLSCOPE, tableName=CLIENT_SCOPE_CLIENT','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('13.0.0-increase-column-size-federated','keycloak','META-INF/jpa-changelog-13.0.0.xml','2025-03-31 04:53:21',94,'EXECUTED','9:43c0c1055b6761b4b3e89de76d612ccf','modifyDataType columnName=CLIENT_ID, tableName=CLIENT_SCOPE_CLIENT; modifyDataType columnName=SCOPE_ID, tableName=CLIENT_SCOPE_CLIENT','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('13.0.0-KEYCLOAK-17992-recreate-constraints','keycloak','META-INF/jpa-changelog-13.0.0.xml','2025-03-31 04:53:21',95,'MARK_RAN','9:8bd711fd0330f4fe980494ca43ab1139','addNotNullConstraint columnName=CLIENT_ID, tableName=CLIENT_SCOPE_CLIENT; addNotNullConstraint columnName=SCOPE_ID, tableName=CLIENT_SCOPE_CLIENT; addPrimaryKey constraintName=C_CLI_SCOPE_BIND, tableName=CLIENT_SCOPE_CLIENT; createIndex indexName=...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('json-string-accomodation-fixed','keycloak','META-INF/jpa-changelog-13.0.0.xml','2025-03-31 04:53:21',96,'EXECUTED','9:e07d2bc0970c348bb06fb63b1f82ddbf','addColumn tableName=REALM_ATTRIBUTE; update tableName=REALM_ATTRIBUTE; dropColumn columnName=VALUE, tableName=REALM_ATTRIBUTE; renameColumn newColumnName=VALUE, oldColumnName=VALUE_NEW, tableName=REALM_ATTRIBUTE','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('14.0.0-KEYCLOAK-11019','keycloak','META-INF/jpa-changelog-14.0.0.xml','2025-03-31 04:53:21',97,'EXECUTED','9:24fb8611e97f29989bea412aa38d12b7','createIndex indexName=IDX_OFFLINE_CSS_PRELOAD, tableName=OFFLINE_CLIENT_SESSION; createIndex indexName=IDX_OFFLINE_USS_BY_USER, tableName=OFFLINE_USER_SESSION; createIndex indexName=IDX_OFFLINE_USS_BY_USERSESS, tableName=OFFLINE_USER_SESSION','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('14.0.0-KEYCLOAK-18286','keycloak','META-INF/jpa-changelog-14.0.0.xml','2025-03-31 04:53:21',98,'MARK_RAN','9:259f89014ce2506ee84740cbf7163aa7','createIndex indexName=IDX_CLIENT_ATT_BY_NAME_VALUE, tableName=CLIENT_ATTRIBUTES','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('14.0.0-KEYCLOAK-18286-revert','keycloak','META-INF/jpa-changelog-14.0.0.xml','2025-03-31 04:53:21',99,'MARK_RAN','9:04baaf56c116ed19951cbc2cca584022','dropIndex indexName=IDX_CLIENT_ATT_BY_NAME_VALUE, tableName=CLIENT_ATTRIBUTES','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('14.0.0-KEYCLOAK-18286-supported-dbs','keycloak','META-INF/jpa-changelog-14.0.0.xml','2025-03-31 04:53:21',100,'EXECUTED','9:bd2bd0fc7768cf0845ac96a8786fa735','createIndex indexName=IDX_CLIENT_ATT_BY_NAME_VALUE, tableName=CLIENT_ATTRIBUTES','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('14.0.0-KEYCLOAK-18286-unsupported-dbs','keycloak','META-INF/jpa-changelog-14.0.0.xml','2025-03-31 04:53:21',101,'MARK_RAN','9:d3d977031d431db16e2c181ce49d73e9','createIndex indexName=IDX_CLIENT_ATT_BY_NAME_VALUE, tableName=CLIENT_ATTRIBUTES','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('KEYCLOAK-17267-add-index-to-user-attributes','keycloak','META-INF/jpa-changelog-14.0.0.xml','2025-03-31 04:53:21',102,'EXECUTED','9:0b305d8d1277f3a89a0a53a659ad274c','createIndex indexName=IDX_USER_ATTRIBUTE_NAME, tableName=USER_ATTRIBUTE','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('KEYCLOAK-18146-add-saml-art-binding-identifier','keycloak','META-INF/jpa-changelog-14.0.0.xml','2025-03-31 04:53:21',103,'EXECUTED','9:2c374ad2cdfe20e2905a84c8fac48460','customChange','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('15.0.0-KEYCLOAK-18467','keycloak','META-INF/jpa-changelog-15.0.0.xml','2025-03-31 04:53:21',104,'EXECUTED','9:47a760639ac597360a8219f5b768b4de','addColumn tableName=REALM_LOCALIZATIONS; update tableName=REALM_LOCALIZATIONS; dropColumn columnName=TEXTS, tableName=REALM_LOCALIZATIONS; renameColumn newColumnName=TEXTS, oldColumnName=TEXTS_NEW, tableName=REALM_LOCALIZATIONS; addNotNullConstrai...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('17.0.0-9562','keycloak','META-INF/jpa-changelog-17.0.0.xml','2025-03-31 04:53:22',105,'EXECUTED','9:a6272f0576727dd8cad2522335f5d99e','createIndex indexName=IDX_USER_SERVICE_ACCOUNT, tableName=USER_ENTITY','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('18.0.0-10625-IDX_ADMIN_EVENT_TIME','keycloak','META-INF/jpa-changelog-18.0.0.xml','2025-03-31 04:53:22',106,'EXECUTED','9:015479dbd691d9cc8669282f4828c41d','createIndex indexName=IDX_ADMIN_EVENT_TIME, tableName=ADMIN_EVENT_ENTITY','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('19.0.0-10135','keycloak','META-INF/jpa-changelog-19.0.0.xml','2025-03-31 04:53:22',107,'EXECUTED','9:9518e495fdd22f78ad6425cc30630221','customChange','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('20.0.0-12964-supported-dbs','keycloak','META-INF/jpa-changelog-20.0.0.xml','2025-03-31 04:53:22',108,'EXECUTED','9:f2e1331a71e0aa85e5608fe42f7f681c','createIndex indexName=IDX_GROUP_ATT_BY_NAME_VALUE, tableName=GROUP_ATTRIBUTE','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('20.0.0-12964-unsupported-dbs','keycloak','META-INF/jpa-changelog-20.0.0.xml','2025-03-31 04:53:22',109,'MARK_RAN','9:1a6fcaa85e20bdeae0a9ce49b41946a5','createIndex indexName=IDX_GROUP_ATT_BY_NAME_VALUE, tableName=GROUP_ATTRIBUTE','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('client-attributes-string-accomodation-fixed','keycloak','META-INF/jpa-changelog-20.0.0.xml','2025-03-31 04:53:22',110,'EXECUTED','9:3f332e13e90739ed0c35b0b25b7822ca','addColumn tableName=CLIENT_ATTRIBUTES; update tableName=CLIENT_ATTRIBUTES; dropColumn columnName=VALUE, tableName=CLIENT_ATTRIBUTES; renameColumn newColumnName=VALUE, oldColumnName=VALUE_NEW, tableName=CLIENT_ATTRIBUTES','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('21.0.2-17277','keycloak','META-INF/jpa-changelog-21.0.2.xml','2025-03-31 04:53:22',111,'EXECUTED','9:7ee1f7a3fb8f5588f171fb9a6ab623c0','customChange','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('21.1.0-19404','keycloak','META-INF/jpa-changelog-21.1.0.xml','2025-03-31 04:53:22',112,'EXECUTED','9:3d7e830b52f33676b9d64f7f2b2ea634','modifyDataType columnName=DECISION_STRATEGY, tableName=RESOURCE_SERVER_POLICY; modifyDataType columnName=LOGIC, tableName=RESOURCE_SERVER_POLICY; modifyDataType columnName=POLICY_ENFORCE_MODE, tableName=RESOURCE_SERVER','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('21.1.0-19404-2','keycloak','META-INF/jpa-changelog-21.1.0.xml','2025-03-31 04:53:22',113,'MARK_RAN','9:627d032e3ef2c06c0e1f73d2ae25c26c','addColumn tableName=RESOURCE_SERVER_POLICY; update tableName=RESOURCE_SERVER_POLICY; dropColumn columnName=DECISION_STRATEGY, tableName=RESOURCE_SERVER_POLICY; renameColumn newColumnName=DECISION_STRATEGY, oldColumnName=DECISION_STRATEGY_NEW, tabl...','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('22.0.0-17484-updated','keycloak','META-INF/jpa-changelog-22.0.0.xml','2025-03-31 04:53:22',114,'EXECUTED','9:90af0bfd30cafc17b9f4d6eccd92b8b3','customChange','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('22.0.5-24031','keycloak','META-INF/jpa-changelog-22.0.0.xml','2025-03-31 04:53:22',115,'MARK_RAN','9:a60d2d7b315ec2d3eba9e2f145f9df28','customChange','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('23.0.0-12062','keycloak','META-INF/jpa-changelog-23.0.0.xml','2025-03-31 04:53:23',116,'EXECUTED','9:2168fbe728fec46ae9baf15bf80927b8','addColumn tableName=COMPONENT_CONFIG; update tableName=COMPONENT_CONFIG; dropColumn columnName=VALUE, tableName=COMPONENT_CONFIG; renameColumn newColumnName=VALUE, oldColumnName=VALUE_NEW, tableName=COMPONENT_CONFIG','',NULL,'4.23.2',NULL,NULL,'3396748200'),
('23.0.0-17258','keycloak','META-INF/jpa-changelog-23.0.0.xml','2025-03-31 04:53:23',117,'EXECUTED','9:36506d679a83bbfda85a27ea1864dca8','addColumn tableName=EVENT_ENTITY','',NULL,'4.23.2',NULL,NULL,'3396748200');
/*!40000 ALTER TABLE `DATABASECHANGELOG` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `DATABASECHANGELOGLOCK`
--

DROP TABLE IF EXISTS `DATABASECHANGELOGLOCK`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DATABASECHANGELOGLOCK` (
  `ID` int(11) NOT NULL,
  `LOCKED` bit(1) NOT NULL,
  `LOCKGRANTED` datetime DEFAULT NULL,
  `LOCKEDBY` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `DATABASECHANGELOGLOCK`
--

LOCK TABLES `DATABASECHANGELOGLOCK` WRITE;
/*!40000 ALTER TABLE `DATABASECHANGELOGLOCK` DISABLE KEYS */;
INSERT INTO `DATABASECHANGELOGLOCK` VALUES
(1,'\0',NULL,NULL),
(1000,'\0',NULL,NULL),
(1001,'\0',NULL,NULL);
/*!40000 ALTER TABLE `DATABASECHANGELOGLOCK` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `DEFAULT_CLIENT_SCOPE`
--

DROP TABLE IF EXISTS `DEFAULT_CLIENT_SCOPE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DEFAULT_CLIENT_SCOPE` (
  `REALM_ID` varchar(36) NOT NULL,
  `SCOPE_ID` varchar(36) NOT NULL,
  `DEFAULT_SCOPE` bit(1) NOT NULL DEFAULT b'0',
  PRIMARY KEY (`REALM_ID`,`SCOPE_ID`),
  KEY `IDX_DEFCLS_REALM` (`REALM_ID`),
  KEY `IDX_DEFCLS_SCOPE` (`SCOPE_ID`),
  CONSTRAINT `FK_R_DEF_CLI_SCOPE_REALM` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `DEFAULT_CLIENT_SCOPE`
--

LOCK TABLES `DEFAULT_CLIENT_SCOPE` WRITE;
/*!40000 ALTER TABLE `DEFAULT_CLIENT_SCOPE` DISABLE KEYS */;
INSERT INTO `DEFAULT_CLIENT_SCOPE` VALUES
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','36f24f6c-f32a-4537-977b-dff0b0de9470',''),
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','43bd3461-2d5e-412c-96cd-125e4e2785b5','\0'),
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d',''),
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','5e701f0b-2581-4458-a171-fdf2aa34d1c9',''),
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','7538c9cb-f57d-4358-a073-1eb9bcbe0f29','\0'),
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','92fb03e0-4c6d-4b25-ac33-54ace6e61139',''),
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','b9130729-e811-4118-9c3c-2fe95a93bd5a',''),
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','c47be204-f074-4670-8bd3-fd526ef41655','\0'),
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','e3c658f5-9390-4b8d-a333-062a54a65ba5',''),
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','e5c89cef-3d47-4a27-882c-9cd6cb52d7ff','\0'),
('dab18c5a-b240-4256-b8a9-31247dda96ac','1afbd77b-8fda-4a7a-a1a8-044dafaee9f1','\0'),
('dab18c5a-b240-4256-b8a9-31247dda96ac','32ad3d0c-d877-4811-bcfd-474b40ad1e8d',''),
('dab18c5a-b240-4256-b8a9-31247dda96ac','4277aaef-8983-44c7-81c6-d3c3485aa3fa','\0'),
('dab18c5a-b240-4256-b8a9-31247dda96ac','608e02cb-3f63-4e89-9258-fbd1c7c6d8f0',''),
('dab18c5a-b240-4256-b8a9-31247dda96ac','7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706',''),
('dab18c5a-b240-4256-b8a9-31247dda96ac','980ab3c2-627a-4b0f-82fe-3e9216cdda7f',''),
('dab18c5a-b240-4256-b8a9-31247dda96ac','a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c','\0'),
('dab18c5a-b240-4256-b8a9-31247dda96ac','cecca841-4cd1-4f09-8724-fa20c73281b8','\0'),
('dab18c5a-b240-4256-b8a9-31247dda96ac','e3f1e796-a25e-4e58-a07d-5362a6d0139c',''),
('dab18c5a-b240-4256-b8a9-31247dda96ac','f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9','');
/*!40000 ALTER TABLE `DEFAULT_CLIENT_SCOPE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `EVENT_ENTITY`
--

DROP TABLE IF EXISTS `EVENT_ENTITY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EVENT_ENTITY` (
  `ID` varchar(36) NOT NULL,
  `CLIENT_ID` varchar(255) DEFAULT NULL,
  `DETAILS_JSON` text DEFAULT NULL,
  `ERROR` varchar(255) DEFAULT NULL,
  `IP_ADDRESS` varchar(255) DEFAULT NULL,
  `REALM_ID` varchar(255) DEFAULT NULL,
  `SESSION_ID` varchar(255) DEFAULT NULL,
  `EVENT_TIME` bigint(20) DEFAULT NULL,
  `TYPE` varchar(255) DEFAULT NULL,
  `USER_ID` varchar(255) DEFAULT NULL,
  `DETAILS_JSON_LONG_VALUE` longtext CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_EVENT_TIME` (`REALM_ID`,`EVENT_TIME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `EVENT_ENTITY`
--

LOCK TABLES `EVENT_ENTITY` WRITE;
/*!40000 ALTER TABLE `EVENT_ENTITY` DISABLE KEYS */;
INSERT INTO `EVENT_ENTITY` VALUES
('07003fea-3c14-464f-8c2d-c8245a438014','contrabass-client',NULL,NULL,'172.20.10.231','dab18c5a-b240-4256-b8a9-31247dda96ac','0b7481cd-f6e8-4608-9799-3e0ceb23cac9',1743396892516,'LOGIN','650758f6-3448-4985-a3d6-d925830b1cb5','{\"auth_method\":\"openid-connect\",\"auth_type\":\"code\",\"redirect_uri\":\"https://contrabass.os:9443/oauth2/callback\",\"consent\":\"no_consent_required\",\"code_id\":\"0b7481cd-f6e8-4608-9799-3e0ceb23cac9\",\"username\":\"maestro@okestro.com\"}'),
('24ac18ff-7999-4121-821c-44c111222407','contrabass-client',NULL,NULL,'172.20.10.231','dab18c5a-b240-4256-b8a9-31247dda96ac','cd17da48-f10d-4093-ad18-aec0025d4595',1743556846830,'LOGIN','650758f6-3448-4985-a3d6-d925830b1cb5','{\"auth_method\":\"openid-connect\",\"auth_type\":\"code\",\"redirect_uri\":\"https://contrabass.os:9443/oauth2/callback\",\"consent\":\"no_consent_required\",\"code_id\":\"cd17da48-f10d-4093-ad18-aec0025d4595\",\"username\":\"maestro@okestro.com\"}'),
('41803dbc-958e-4cd3-8b65-c188beb269f7','contrabass-client',NULL,NULL,'10.4.1.21','dab18c5a-b240-4256-b8a9-31247dda96ac','0b7481cd-f6e8-4608-9799-3e0ceb23cac9',1743396892651,'CODE_TO_TOKEN','650758f6-3448-4985-a3d6-d925830b1cb5','{\"token_id\":\"ef641b5a-d20c-40ed-8147-479cd27b2209\",\"grant_type\":\"authorization_code\",\"scope\":\"openid profile email\",\"code_id\":\"0b7481cd-f6e8-4608-9799-3e0ceb23cac9\",\"client_auth_method\":\"client-secret\"}'),
('6a35927f-10a4-463c-8572-04447ed5ea57','contrabass-client',NULL,NULL,'10.4.1.21','dab18c5a-b240-4256-b8a9-31247dda96ac','a7b2c6c3-9503-44ea-b39c-626599da84ae',1743511759500,'CODE_TO_TOKEN','650758f6-3448-4985-a3d6-d925830b1cb5','{\"token_id\":\"df4ef3cc-8526-45bb-8f6f-e94ea2ef28b8\",\"grant_type\":\"authorization_code\",\"scope\":\"openid profile email\",\"code_id\":\"a7b2c6c3-9503-44ea-b39c-626599da84ae\",\"client_auth_method\":\"client-secret\"}'),
('8372d298-85fe-40d2-98b9-3aa1766d4ca7','contrabass-client',NULL,NULL,'10.4.1.21','dab18c5a-b240-4256-b8a9-31247dda96ac','cd17da48-f10d-4093-ad18-aec0025d4595',1743556846883,'CODE_TO_TOKEN','650758f6-3448-4985-a3d6-d925830b1cb5','{\"token_id\":\"c8e34194-3ebb-4803-9bd6-82867478ed30\",\"grant_type\":\"authorization_code\",\"scope\":\"openid profile email\",\"code_id\":\"cd17da48-f10d-4093-ad18-aec0025d4595\",\"client_auth_method\":\"client-secret\"}'),
('f009d740-a074-4578-9f4b-ea8b688c1711','contrabass-client',NULL,NULL,'172.20.10.231','dab18c5a-b240-4256-b8a9-31247dda96ac','a7b2c6c3-9503-44ea-b39c-626599da84ae',1743511759432,'LOGIN','650758f6-3448-4985-a3d6-d925830b1cb5','{\"auth_method\":\"openid-connect\",\"auth_type\":\"code\",\"redirect_uri\":\"https://contrabass.os:9443/oauth2/callback\",\"consent\":\"no_consent_required\",\"code_id\":\"a7b2c6c3-9503-44ea-b39c-626599da84ae\",\"username\":\"maestro@okestro.com\"}');
/*!40000 ALTER TABLE `EVENT_ENTITY` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `FEDERATED_IDENTITY`
--

DROP TABLE IF EXISTS `FEDERATED_IDENTITY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FEDERATED_IDENTITY` (
  `IDENTITY_PROVIDER` varchar(255) NOT NULL,
  `REALM_ID` varchar(36) DEFAULT NULL,
  `FEDERATED_USER_ID` varchar(255) DEFAULT NULL,
  `FEDERATED_USERNAME` varchar(255) DEFAULT NULL,
  `TOKEN` text DEFAULT NULL,
  `USER_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`IDENTITY_PROVIDER`,`USER_ID`),
  KEY `IDX_FEDIDENTITY_USER` (`USER_ID`),
  KEY `IDX_FEDIDENTITY_FEDUSER` (`FEDERATED_USER_ID`),
  CONSTRAINT `FK404288B92EF007A6` FOREIGN KEY (`USER_ID`) REFERENCES `USER_ENTITY` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `FEDERATED_IDENTITY`
--

LOCK TABLES `FEDERATED_IDENTITY` WRITE;
/*!40000 ALTER TABLE `FEDERATED_IDENTITY` DISABLE KEYS */;
/*!40000 ALTER TABLE `FEDERATED_IDENTITY` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `FEDERATED_USER`
--

DROP TABLE IF EXISTS `FEDERATED_USER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FEDERATED_USER` (
  `ID` varchar(255) NOT NULL,
  `STORAGE_PROVIDER_ID` varchar(255) DEFAULT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `FEDERATED_USER`
--

LOCK TABLES `FEDERATED_USER` WRITE;
/*!40000 ALTER TABLE `FEDERATED_USER` DISABLE KEYS */;
/*!40000 ALTER TABLE `FEDERATED_USER` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `FED_USER_ATTRIBUTE`
--

DROP TABLE IF EXISTS `FED_USER_ATTRIBUTE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FED_USER_ATTRIBUTE` (
  `ID` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `USER_ID` varchar(255) NOT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  `STORAGE_PROVIDER_ID` varchar(36) DEFAULT NULL,
  `VALUE` text DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_FU_ATTRIBUTE` (`USER_ID`,`REALM_ID`,`NAME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `FED_USER_ATTRIBUTE`
--

LOCK TABLES `FED_USER_ATTRIBUTE` WRITE;
/*!40000 ALTER TABLE `FED_USER_ATTRIBUTE` DISABLE KEYS */;
/*!40000 ALTER TABLE `FED_USER_ATTRIBUTE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `FED_USER_CONSENT`
--

DROP TABLE IF EXISTS `FED_USER_CONSENT`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FED_USER_CONSENT` (
  `ID` varchar(36) NOT NULL,
  `CLIENT_ID` varchar(255) DEFAULT NULL,
  `USER_ID` varchar(255) NOT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  `STORAGE_PROVIDER_ID` varchar(36) DEFAULT NULL,
  `CREATED_DATE` bigint(20) DEFAULT NULL,
  `LAST_UPDATED_DATE` bigint(20) DEFAULT NULL,
  `CLIENT_STORAGE_PROVIDER` varchar(36) DEFAULT NULL,
  `EXTERNAL_CLIENT_ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_FU_CONSENT` (`USER_ID`,`CLIENT_ID`),
  KEY `IDX_FU_CONSENT_RU` (`REALM_ID`,`USER_ID`),
  KEY `IDX_FU_CNSNT_EXT` (`USER_ID`,`CLIENT_STORAGE_PROVIDER`,`EXTERNAL_CLIENT_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `FED_USER_CONSENT`
--

LOCK TABLES `FED_USER_CONSENT` WRITE;
/*!40000 ALTER TABLE `FED_USER_CONSENT` DISABLE KEYS */;
/*!40000 ALTER TABLE `FED_USER_CONSENT` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `FED_USER_CONSENT_CL_SCOPE`
--

DROP TABLE IF EXISTS `FED_USER_CONSENT_CL_SCOPE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FED_USER_CONSENT_CL_SCOPE` (
  `USER_CONSENT_ID` varchar(36) NOT NULL,
  `SCOPE_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`USER_CONSENT_ID`,`SCOPE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `FED_USER_CONSENT_CL_SCOPE`
--

LOCK TABLES `FED_USER_CONSENT_CL_SCOPE` WRITE;
/*!40000 ALTER TABLE `FED_USER_CONSENT_CL_SCOPE` DISABLE KEYS */;
/*!40000 ALTER TABLE `FED_USER_CONSENT_CL_SCOPE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `FED_USER_CREDENTIAL`
--

DROP TABLE IF EXISTS `FED_USER_CREDENTIAL`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FED_USER_CREDENTIAL` (
  `ID` varchar(36) NOT NULL,
  `SALT` tinyblob DEFAULT NULL,
  `TYPE` varchar(255) DEFAULT NULL,
  `CREATED_DATE` bigint(20) DEFAULT NULL,
  `USER_ID` varchar(255) NOT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  `STORAGE_PROVIDER_ID` varchar(36) DEFAULT NULL,
  `USER_LABEL` varchar(255) DEFAULT NULL,
  `SECRET_DATA` longtext DEFAULT NULL,
  `CREDENTIAL_DATA` longtext DEFAULT NULL,
  `PRIORITY` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_FU_CREDENTIAL` (`USER_ID`,`TYPE`),
  KEY `IDX_FU_CREDENTIAL_RU` (`REALM_ID`,`USER_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `FED_USER_CREDENTIAL`
--

LOCK TABLES `FED_USER_CREDENTIAL` WRITE;
/*!40000 ALTER TABLE `FED_USER_CREDENTIAL` DISABLE KEYS */;
/*!40000 ALTER TABLE `FED_USER_CREDENTIAL` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `FED_USER_GROUP_MEMBERSHIP`
--

DROP TABLE IF EXISTS `FED_USER_GROUP_MEMBERSHIP`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FED_USER_GROUP_MEMBERSHIP` (
  `GROUP_ID` varchar(36) NOT NULL,
  `USER_ID` varchar(255) NOT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  `STORAGE_PROVIDER_ID` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`GROUP_ID`,`USER_ID`),
  KEY `IDX_FU_GROUP_MEMBERSHIP` (`USER_ID`,`GROUP_ID`),
  KEY `IDX_FU_GROUP_MEMBERSHIP_RU` (`REALM_ID`,`USER_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `FED_USER_GROUP_MEMBERSHIP`
--

LOCK TABLES `FED_USER_GROUP_MEMBERSHIP` WRITE;
/*!40000 ALTER TABLE `FED_USER_GROUP_MEMBERSHIP` DISABLE KEYS */;
/*!40000 ALTER TABLE `FED_USER_GROUP_MEMBERSHIP` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `FED_USER_REQUIRED_ACTION`
--

DROP TABLE IF EXISTS `FED_USER_REQUIRED_ACTION`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FED_USER_REQUIRED_ACTION` (
  `REQUIRED_ACTION` varchar(255) NOT NULL DEFAULT ' ',
  `USER_ID` varchar(255) NOT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  `STORAGE_PROVIDER_ID` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`REQUIRED_ACTION`,`USER_ID`),
  KEY `IDX_FU_REQUIRED_ACTION` (`USER_ID`,`REQUIRED_ACTION`),
  KEY `IDX_FU_REQUIRED_ACTION_RU` (`REALM_ID`,`USER_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `FED_USER_REQUIRED_ACTION`
--

LOCK TABLES `FED_USER_REQUIRED_ACTION` WRITE;
/*!40000 ALTER TABLE `FED_USER_REQUIRED_ACTION` DISABLE KEYS */;
/*!40000 ALTER TABLE `FED_USER_REQUIRED_ACTION` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `FED_USER_ROLE_MAPPING`
--

DROP TABLE IF EXISTS `FED_USER_ROLE_MAPPING`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FED_USER_ROLE_MAPPING` (
  `ROLE_ID` varchar(36) NOT NULL,
  `USER_ID` varchar(255) NOT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  `STORAGE_PROVIDER_ID` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`ROLE_ID`,`USER_ID`),
  KEY `IDX_FU_ROLE_MAPPING` (`USER_ID`,`ROLE_ID`),
  KEY `IDX_FU_ROLE_MAPPING_RU` (`REALM_ID`,`USER_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `FED_USER_ROLE_MAPPING`
--

LOCK TABLES `FED_USER_ROLE_MAPPING` WRITE;
/*!40000 ALTER TABLE `FED_USER_ROLE_MAPPING` DISABLE KEYS */;
/*!40000 ALTER TABLE `FED_USER_ROLE_MAPPING` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `GROUP_ATTRIBUTE`
--

DROP TABLE IF EXISTS `GROUP_ATTRIBUTE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `GROUP_ATTRIBUTE` (
  `ID` varchar(36) NOT NULL DEFAULT 'sybase-needs-something-here',
  `NAME` varchar(255) NOT NULL,
  `VALUE` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `GROUP_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_GROUP_ATTR_GROUP` (`GROUP_ID`),
  KEY `IDX_GROUP_ATT_BY_NAME_VALUE` (`NAME`,`VALUE`),
  CONSTRAINT `FK_GROUP_ATTRIBUTE_GROUP` FOREIGN KEY (`GROUP_ID`) REFERENCES `KEYCLOAK_GROUP` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `GROUP_ATTRIBUTE`
--

LOCK TABLES `GROUP_ATTRIBUTE` WRITE;
/*!40000 ALTER TABLE `GROUP_ATTRIBUTE` DISABLE KEYS */;
/*!40000 ALTER TABLE `GROUP_ATTRIBUTE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `GROUP_ROLE_MAPPING`
--

DROP TABLE IF EXISTS `GROUP_ROLE_MAPPING`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `GROUP_ROLE_MAPPING` (
  `ROLE_ID` varchar(36) NOT NULL,
  `GROUP_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`ROLE_ID`,`GROUP_ID`),
  KEY `IDX_GROUP_ROLE_MAPP_GROUP` (`GROUP_ID`),
  CONSTRAINT `FK_GROUP_ROLE_GROUP` FOREIGN KEY (`GROUP_ID`) REFERENCES `KEYCLOAK_GROUP` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `GROUP_ROLE_MAPPING`
--

LOCK TABLES `GROUP_ROLE_MAPPING` WRITE;
/*!40000 ALTER TABLE `GROUP_ROLE_MAPPING` DISABLE KEYS */;
/*!40000 ALTER TABLE `GROUP_ROLE_MAPPING` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `IDENTITY_PROVIDER`
--

DROP TABLE IF EXISTS `IDENTITY_PROVIDER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `IDENTITY_PROVIDER` (
  `INTERNAL_ID` varchar(36) NOT NULL,
  `ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `PROVIDER_ALIAS` varchar(255) DEFAULT NULL,
  `PROVIDER_ID` varchar(255) DEFAULT NULL,
  `STORE_TOKEN` bit(1) NOT NULL DEFAULT b'0',
  `AUTHENTICATE_BY_DEFAULT` bit(1) NOT NULL DEFAULT b'0',
  `REALM_ID` varchar(36) DEFAULT NULL,
  `ADD_TOKEN_ROLE` bit(1) NOT NULL DEFAULT b'1',
  `TRUST_EMAIL` bit(1) NOT NULL DEFAULT b'0',
  `FIRST_BROKER_LOGIN_FLOW_ID` varchar(36) DEFAULT NULL,
  `POST_BROKER_LOGIN_FLOW_ID` varchar(36) DEFAULT NULL,
  `PROVIDER_DISPLAY_NAME` varchar(255) DEFAULT NULL,
  `LINK_ONLY` bit(1) NOT NULL DEFAULT b'0',
  PRIMARY KEY (`INTERNAL_ID`),
  UNIQUE KEY `UK_2DAELWNIBJI49AVXSRTUF6XJ33` (`PROVIDER_ALIAS`,`REALM_ID`),
  KEY `IDX_IDENT_PROV_REALM` (`REALM_ID`),
  CONSTRAINT `FK2B4EBC52AE5C3B34` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `IDENTITY_PROVIDER`
--

LOCK TABLES `IDENTITY_PROVIDER` WRITE;
/*!40000 ALTER TABLE `IDENTITY_PROVIDER` DISABLE KEYS */;
/*!40000 ALTER TABLE `IDENTITY_PROVIDER` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `IDENTITY_PROVIDER_CONFIG`
--

DROP TABLE IF EXISTS `IDENTITY_PROVIDER_CONFIG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `IDENTITY_PROVIDER_CONFIG` (
  `IDENTITY_PROVIDER_ID` varchar(36) NOT NULL,
  `VALUE` longtext DEFAULT NULL,
  `NAME` varchar(255) NOT NULL,
  PRIMARY KEY (`IDENTITY_PROVIDER_ID`,`NAME`),
  CONSTRAINT `FKDC4897CF864C4E43` FOREIGN KEY (`IDENTITY_PROVIDER_ID`) REFERENCES `IDENTITY_PROVIDER` (`INTERNAL_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `IDENTITY_PROVIDER_CONFIG`
--

LOCK TABLES `IDENTITY_PROVIDER_CONFIG` WRITE;
/*!40000 ALTER TABLE `IDENTITY_PROVIDER_CONFIG` DISABLE KEYS */;
/*!40000 ALTER TABLE `IDENTITY_PROVIDER_CONFIG` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `IDENTITY_PROVIDER_MAPPER`
--

DROP TABLE IF EXISTS `IDENTITY_PROVIDER_MAPPER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `IDENTITY_PROVIDER_MAPPER` (
  `ID` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `IDP_ALIAS` varchar(255) NOT NULL,
  `IDP_MAPPER_NAME` varchar(255) NOT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_ID_PROV_MAPP_REALM` (`REALM_ID`),
  CONSTRAINT `FK_IDPM_REALM` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `IDENTITY_PROVIDER_MAPPER`
--

LOCK TABLES `IDENTITY_PROVIDER_MAPPER` WRITE;
/*!40000 ALTER TABLE `IDENTITY_PROVIDER_MAPPER` DISABLE KEYS */;
/*!40000 ALTER TABLE `IDENTITY_PROVIDER_MAPPER` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `IDP_MAPPER_CONFIG`
--

DROP TABLE IF EXISTS `IDP_MAPPER_CONFIG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `IDP_MAPPER_CONFIG` (
  `IDP_MAPPER_ID` varchar(36) NOT NULL,
  `VALUE` longtext DEFAULT NULL,
  `NAME` varchar(255) NOT NULL,
  PRIMARY KEY (`IDP_MAPPER_ID`,`NAME`),
  CONSTRAINT `FK_IDPMCONFIG` FOREIGN KEY (`IDP_MAPPER_ID`) REFERENCES `IDENTITY_PROVIDER_MAPPER` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `IDP_MAPPER_CONFIG`
--

LOCK TABLES `IDP_MAPPER_CONFIG` WRITE;
/*!40000 ALTER TABLE `IDP_MAPPER_CONFIG` DISABLE KEYS */;
/*!40000 ALTER TABLE `IDP_MAPPER_CONFIG` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `KEYCLOAK_GROUP`
--

DROP TABLE IF EXISTS `KEYCLOAK_GROUP`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `KEYCLOAK_GROUP` (
  `ID` varchar(36) NOT NULL,
  `NAME` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `PARENT_GROUP` varchar(36) NOT NULL,
  `REALM_ID` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `SIBLING_NAMES` (`REALM_ID`,`PARENT_GROUP`,`NAME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `KEYCLOAK_GROUP`
--

LOCK TABLES `KEYCLOAK_GROUP` WRITE;
/*!40000 ALTER TABLE `KEYCLOAK_GROUP` DISABLE KEYS */;
/*!40000 ALTER TABLE `KEYCLOAK_GROUP` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `KEYCLOAK_ROLE`
--

DROP TABLE IF EXISTS `KEYCLOAK_ROLE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `KEYCLOAK_ROLE` (
  `ID` varchar(36) NOT NULL,
  `CLIENT_REALM_CONSTRAINT` varchar(255) DEFAULT NULL,
  `CLIENT_ROLE` bit(1) DEFAULT NULL,
  `DESCRIPTION` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `NAME` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `REALM_ID` varchar(255) DEFAULT NULL,
  `CLIENT` varchar(36) DEFAULT NULL,
  `REALM` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UK_J3RWUVD56ONTGSUHOGM184WW2-2` (`NAME`,`CLIENT_REALM_CONSTRAINT`),
  KEY `IDX_KEYCLOAK_ROLE_CLIENT` (`CLIENT`),
  KEY `IDX_KEYCLOAK_ROLE_REALM` (`REALM`),
  CONSTRAINT `FK_6VYQFE4CN4WLQ8R6KT5VDSJ5C` FOREIGN KEY (`REALM`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `KEYCLOAK_ROLE`
--

LOCK TABLES `KEYCLOAK_ROLE` WRITE;
/*!40000 ALTER TABLE `KEYCLOAK_ROLE` DISABLE KEYS */;
INSERT INTO `KEYCLOAK_ROLE` VALUES
('00d93ccb-291c-427e-968f-2f4b591c1c45','a6f6cb61-4f2a-4932-a629-b58e25de88ca','','${role_read-token}','read-token','dab18c5a-b240-4256-b8a9-31247dda96ac','a6f6cb61-4f2a-4932-a629-b58e25de88ca',NULL),
('04b9f1fa-05af-4d6e-84b2-5547bb07db93','cf784c13-493e-4d43-86ee-8b9c81845b12','','${role_manage-account}','manage-account','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','cf784c13-493e-4d43-86ee-8b9c81845b12',NULL),
('0603741c-defd-49b1-9752-a653420278e4','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_query-realms}','query-realms','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('0c717c17-cbf2-431e-849b-ba3ab501c84e','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_view-clients}','view-clients','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('0e601c18-df7b-471a-9a87-4baf6a4dadbc','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_view-authorization}','view-authorization','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('0f779c01-e220-4a34-8464-c8244fb0696f','cf784c13-493e-4d43-86ee-8b9c81845b12','','${role_view-applications}','view-applications','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','cf784c13-493e-4d43-86ee-8b9c81845b12',NULL),
('1ab2166c-4977-4d5d-bda2-ff551379b87c','c4e639d7-8646-4f98-a9ba-c66d912ea13b','',NULL,'uma_protection','dab18c5a-b240-4256-b8a9-31247dda96ac','c4e639d7-8646-4f98-a9ba-c66d912ea13b',NULL),
('1bd065ea-b8b1-4c30-8f9d-811a635ebd21','dab18c5a-b240-4256-b8a9-31247dda96ac','\0','${role_uma_authorization}','uma_authorization','dab18c5a-b240-4256-b8a9-31247dda96ac',NULL,NULL),
('24015241-7cfc-4c80-89c4-c188ace09d04','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_view-identity-providers}','view-identity-providers','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('2509be78-470d-45f3-8f0e-983a6b564820','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_create-client}','create-client','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('2c33c34f-3c78-49bc-9678-0923325e0a52','cf784c13-493e-4d43-86ee-8b9c81845b12','','${role_delete-account}','delete-account','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','cf784c13-493e-4d43-86ee-8b9c81845b12',NULL),
('2c773491-74b6-4d52-a196-14581d950b57','21f67541-6b75-4f76-92e5-a2b7aa97937b','','${role_view-groups}','view-groups','dab18c5a-b240-4256-b8a9-31247dda96ac','21f67541-6b75-4f76-92e5-a2b7aa97937b',NULL),
('2ea0ff4e-e8ba-4b89-b905-90a253a52dc3','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_view-events}','view-events','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('310d6c65-d1e4-4f48-9147-9a3960a7eec1','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_view-events}','view-events','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('32967061-2daa-4b03-9c98-fea124508e49','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_view-users}','view-users','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('367f6def-88d7-4ff8-94bf-e94a395ff5e9','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_manage-authorization}','manage-authorization','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('39cb7bb4-e9f1-4a04-96ee-09b239f55189','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_manage-realm}','manage-realm','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('3b072ba0-29ed-4177-91be-1c9423b1bdd6','21f67541-6b75-4f76-92e5-a2b7aa97937b','','${role_manage-account-links}','manage-account-links','dab18c5a-b240-4256-b8a9-31247dda96ac','21f67541-6b75-4f76-92e5-a2b7aa97937b',NULL),
('40cfa785-fcdd-4b9c-bd00-3c087cbecb73','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_view-identity-providers}','view-identity-providers','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('40ecc019-54d6-439e-a3f6-248dee4348d7','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_view-clients}','view-clients','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('41469b32-8a9b-41c6-b95b-510f0b43be46','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_realm-admin}','realm-admin','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('42792b2f-1030-439a-9649-f79abe962874','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_view-realm}','view-realm','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('4565f2af-1a67-4a8c-ab81-1179809d2843','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_manage-users}','manage-users','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('47bbb3e1-292e-4030-9f0e-647adce5e895','cf784c13-493e-4d43-86ee-8b9c81845b12','','${role_manage-account-links}','manage-account-links','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','cf784c13-493e-4d43-86ee-8b9c81845b12',NULL),
('4a294e0d-7c96-4075-a877-939285371341','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_view-clients}','view-clients','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('4a6e36e1-951d-4b3a-9195-3a78abd1ddef','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_query-groups}','query-groups','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('4b3020c2-09c2-45d0-a5ff-d608efd20ba2','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_manage-identity-providers}','manage-identity-providers','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('4cf898aa-f789-41da-898f-189dcb198e9a','dab18c5a-b240-4256-b8a9-31247dda96ac','\0','${role_default-roles}','default-roles-contrabass','dab18c5a-b240-4256-b8a9-31247dda96ac',NULL,NULL),
('5007bd80-5988-489e-9025-52a0a49e1e52','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_manage-clients}','manage-clients','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('522675f9-101b-48dd-8bef-6ef49d5b08e7','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_impersonation}','impersonation','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('58078af1-190f-4be7-898e-1483079764d5','cf784c13-493e-4d43-86ee-8b9c81845b12','','${role_manage-consent}','manage-consent','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','cf784c13-493e-4d43-86ee-8b9c81845b12',NULL),
('5971d557-6a46-4205-ae47-477fddde62e6','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_manage-authorization}','manage-authorization','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('60f686a3-e000-48e0-a117-0b4caf34843c','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_query-users}','query-users','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('6c1f7f0a-e3fe-462a-99d9-f700b094fd32','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_manage-clients}','manage-clients','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('6d1173c8-2563-47c0-aafc-931b68643e16','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_view-users}','view-users','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('710ed5d2-9ebc-4b2b-be74-d166fbff73ba','5783ae22-22b9-411d-a1c5-358b4e5b08a4','','${role_read-token}','read-token','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','5783ae22-22b9-411d-a1c5-358b4e5b08a4',NULL),
('7207c52d-ebc5-4c1b-8cf9-cdbc8d42e65c','21f67541-6b75-4f76-92e5-a2b7aa97937b','','${role_manage-account}','manage-account','dab18c5a-b240-4256-b8a9-31247dda96ac','21f67541-6b75-4f76-92e5-a2b7aa97937b',NULL),
('776be460-f860-4ad0-b180-3c34b82db253','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_view-users}','view-users','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('7a606b7f-2ff5-4c0a-82f0-c88f98d349bb','a866e702-403e-4aab-905d-18a4ef119cfe','',NULL,'uma_protection','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('7ae4cbaa-a874-4ca4-aa73-118fe92fd794','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_manage-realm}','manage-realm','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('8235b970-ea81-4074-87e5-7a11d2cbbc1e','cf784c13-493e-4d43-86ee-8b9c81845b12','','${role_view-groups}','view-groups','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','cf784c13-493e-4d43-86ee-8b9c81845b12',NULL),
('82963599-c642-47d1-b310-58c6e81a9360','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','\0','${role_uma_authorization}','uma_authorization','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',NULL,NULL),
('8669a10b-32ee-4240-bd68-5ec6f59a0aa9','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_manage-users}','manage-users','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('8ba12694-c3ad-4d6e-8ab8-d9244e711acf','21f67541-6b75-4f76-92e5-a2b7aa97937b','','${role_manage-consent}','manage-consent','dab18c5a-b240-4256-b8a9-31247dda96ac','21f67541-6b75-4f76-92e5-a2b7aa97937b',NULL),
('8f95351c-cc02-4f96-b883-41b1b2feef8e','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_manage-events}','manage-events','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('908cf046-58fc-48a1-b4a8-7aa424dd2f0d','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_manage-realm}','manage-realm','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('92959480-9696-4b5d-87f2-787493801511','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_view-realm}','view-realm','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('9b322368-4c64-4f00-a4d7-b58d79cc1114','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_query-users}','query-users','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('9bc29a79-b138-454c-b26a-1627f2b29d6e','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_manage-events}','manage-events','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('a072e5cd-12e3-4c5d-8986-be785b879491','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_create-client}','create-client','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('a0f830a0-92b0-4d84-aaba-f19182ad9f5c','21f67541-6b75-4f76-92e5-a2b7aa97937b','','${role_view-consent}','view-consent','dab18c5a-b240-4256-b8a9-31247dda96ac','21f67541-6b75-4f76-92e5-a2b7aa97937b',NULL),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','\0','${role_admin}','admin','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',NULL,NULL),
('a445a268-b8e3-4552-a988-71aac1920a08','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_manage-users}','manage-users','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('a6f80cb2-e076-4d2b-9abe-e1303f66a0c8','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_impersonation}','impersonation','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('a9909df8-475f-4b43-a561-3a0a3e378fe0','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_impersonation}','impersonation','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('bc708560-c9e3-4b04-b300-a33f20cb41e5','dab18c5a-b240-4256-b8a9-31247dda96ac','\0',NULL,'default-roles-maestro-user','dab18c5a-b240-4256-b8a9-31247dda96ac',NULL,NULL),
('c16898f7-7206-4f7f-bc17-8cd0dead927b','cf784c13-493e-4d43-86ee-8b9c81845b12','','${role_view-profile}','view-profile','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','cf784c13-493e-4d43-86ee-8b9c81845b12',NULL),
('c56c4e3d-54a0-4b8b-847b-3fd5b9ea064e','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_query-clients}','query-clients','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('c5d17a69-4e3d-4ecf-9ecb-22254222d892','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_manage-clients}','manage-clients','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('c689852f-3f23-4e75-93cb-dc268de0198b','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','\0','${role_default-roles}','default-roles-master','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',NULL,NULL),
('c80996a8-0853-4048-9692-5f57c834d736','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_query-groups}','query-groups','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('cc67f0fd-4e21-4f7b-8973-f5133e7eb14a','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_view-authorization}','view-authorization','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('cd3b1dfe-1255-43f1-b432-969367725fd1','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_manage-events}','manage-events','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('cfce9bea-2fd5-40f2-8511-fb4d78b459b7','dab18c5a-b240-4256-b8a9-31247dda96ac','\0','${role_offline-access}','offline_access','dab18c5a-b240-4256-b8a9-31247dda96ac',NULL,NULL),
('d689cb68-f4e8-4afd-a6aa-0bd055e25dab','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_view-realm}','view-realm','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('d7192a19-47fc-42b3-ac47-7d4e0e6eff33','21f67541-6b75-4f76-92e5-a2b7aa97937b','','${role_delete-account}','delete-account','dab18c5a-b240-4256-b8a9-31247dda96ac','21f67541-6b75-4f76-92e5-a2b7aa97937b',NULL),
('d8dc70d8-b00d-43ac-a073-349423855750','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','\0','${role_create-realm}','create-realm','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',NULL,NULL),
('d90ebcbb-b0e5-4a6d-880a-40e9b597dcdb','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_query-realms}','query-realms','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('db342d6a-f694-4232-a1d2-c333a0f49d12','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_query-groups}','query-groups','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('df5f87a1-976d-47e6-bec8-00d241ccb192','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','\0','${role_offline-access}','offline_access','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',NULL,NULL),
('e3101047-075d-4185-b483-672411f16b2f','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_view-events}','view-events','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('e43667c9-014c-499f-be0e-d975b0a79d10','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_query-realms}','query-realms','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('e4bfe48b-9fbd-43f3-b839-aad767eb55c9','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_manage-authorization}','manage-authorization','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('e527b9d3-a311-4f3e-a739-b18ec80b5072','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_create-client}','create-client','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('e56f9623-383d-4c1e-98bb-526c9a7ec2d0','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_view-authorization}','view-authorization','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('e644649f-3428-49cb-aeb5-e3ab65124a11','21f67541-6b75-4f76-92e5-a2b7aa97937b','','${role_view-applications}','view-applications','dab18c5a-b240-4256-b8a9-31247dda96ac','21f67541-6b75-4f76-92e5-a2b7aa97937b',NULL),
('e77cbf31-3f9f-4fd7-98d6-fb3874e3d333','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_query-clients}','query-clients','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('ed5e8c9f-eeab-4bbe-b7ea-600b583500e2','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_query-clients}','query-clients','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('ee8156fa-bfe0-4d04-884e-a7eca3192655','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_query-users}','query-users','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('ee8d028f-3562-4f46-8ebe-f39cc3243aba','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b','','${role_manage-identity-providers}','manage-identity-providers','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',NULL),
('f0d7410e-c1b1-42c7-977e-eee8fe1cb287','a866e702-403e-4aab-905d-18a4ef119cfe','','${role_manage-identity-providers}','manage-identity-providers','dab18c5a-b240-4256-b8a9-31247dda96ac','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('f2c4291c-8979-4cc5-a76d-75432e39b15b','9db49952-1afc-4232-98ff-5adb2d5b8e72','','${role_view-identity-providers}','view-identity-providers','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','9db49952-1afc-4232-98ff-5adb2d5b8e72',NULL),
('f4b3e6be-a3dd-42af-a25c-fdfabce36bc6','21f67541-6b75-4f76-92e5-a2b7aa97937b','','${role_view-profile}','view-profile','dab18c5a-b240-4256-b8a9-31247dda96ac','21f67541-6b75-4f76-92e5-a2b7aa97937b',NULL),
('fa9da988-b408-44bc-bc78-df4f5d75ff3d','cf784c13-493e-4d43-86ee-8b9c81845b12','','${role_view-consent}','view-consent','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','cf784c13-493e-4d43-86ee-8b9c81845b12',NULL);
/*!40000 ALTER TABLE `KEYCLOAK_ROLE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `MIGRATION_MODEL`
--

DROP TABLE IF EXISTS `MIGRATION_MODEL`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `MIGRATION_MODEL` (
  `ID` varchar(36) NOT NULL,
  `VERSION` varchar(36) DEFAULT NULL,
  `UPDATE_TIME` bigint(20) NOT NULL DEFAULT 0,
  PRIMARY KEY (`ID`),
  KEY `IDX_UPDATE_TIME` (`UPDATE_TIME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `MIGRATION_MODEL`
--

LOCK TABLES `MIGRATION_MODEL` WRITE;
/*!40000 ALTER TABLE `MIGRATION_MODEL` DISABLE KEYS */;
INSERT INTO `MIGRATION_MODEL` VALUES
('o3q9r','23.0.1',1743396806);
/*!40000 ALTER TABLE `MIGRATION_MODEL` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `OFFLINE_CLIENT_SESSION`
--

DROP TABLE IF EXISTS `OFFLINE_CLIENT_SESSION`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `OFFLINE_CLIENT_SESSION` (
  `USER_SESSION_ID` varchar(36) NOT NULL,
  `CLIENT_ID` varchar(255) NOT NULL,
  `OFFLINE_FLAG` varchar(4) NOT NULL,
  `TIMESTAMP` int(11) DEFAULT NULL,
  `DATA` longtext DEFAULT NULL,
  `CLIENT_STORAGE_PROVIDER` varchar(36) NOT NULL DEFAULT 'local',
  `EXTERNAL_CLIENT_ID` varchar(255) NOT NULL DEFAULT 'local',
  PRIMARY KEY (`USER_SESSION_ID`,`CLIENT_ID`,`CLIENT_STORAGE_PROVIDER`,`EXTERNAL_CLIENT_ID`,`OFFLINE_FLAG`),
  KEY `IDX_US_SESS_ID_ON_CL_SESS` (`USER_SESSION_ID`),
  KEY `IDX_OFFLINE_CSS_PRELOAD` (`CLIENT_ID`,`OFFLINE_FLAG`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `OFFLINE_CLIENT_SESSION`
--

LOCK TABLES `OFFLINE_CLIENT_SESSION` WRITE;
/*!40000 ALTER TABLE `OFFLINE_CLIENT_SESSION` DISABLE KEYS */;
/*!40000 ALTER TABLE `OFFLINE_CLIENT_SESSION` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `OFFLINE_USER_SESSION`
--

DROP TABLE IF EXISTS `OFFLINE_USER_SESSION`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `OFFLINE_USER_SESSION` (
  `USER_SESSION_ID` varchar(36) NOT NULL,
  `USER_ID` varchar(255) DEFAULT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  `CREATED_ON` int(11) NOT NULL,
  `OFFLINE_FLAG` varchar(4) NOT NULL,
  `DATA` longtext DEFAULT NULL,
  `LAST_SESSION_REFRESH` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`USER_SESSION_ID`,`OFFLINE_FLAG`),
  KEY `IDX_OFFLINE_USS_CREATEDON` (`CREATED_ON`),
  KEY `IDX_OFFLINE_USS_PRELOAD` (`OFFLINE_FLAG`,`CREATED_ON`,`USER_SESSION_ID`),
  KEY `IDX_OFFLINE_USS_BY_USER` (`USER_ID`,`REALM_ID`,`OFFLINE_FLAG`),
  KEY `IDX_OFFLINE_USS_BY_USERSESS` (`REALM_ID`,`OFFLINE_FLAG`,`USER_SESSION_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `OFFLINE_USER_SESSION`
--

LOCK TABLES `OFFLINE_USER_SESSION` WRITE;
/*!40000 ALTER TABLE `OFFLINE_USER_SESSION` DISABLE KEYS */;
/*!40000 ALTER TABLE `OFFLINE_USER_SESSION` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `POLICY_CONFIG`
--

DROP TABLE IF EXISTS `POLICY_CONFIG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `POLICY_CONFIG` (
  `POLICY_ID` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `VALUE` longtext DEFAULT NULL,
  PRIMARY KEY (`POLICY_ID`,`NAME`),
  CONSTRAINT `FKDC34197CF864C4E43` FOREIGN KEY (`POLICY_ID`) REFERENCES `RESOURCE_SERVER_POLICY` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `POLICY_CONFIG`
--

LOCK TABLES `POLICY_CONFIG` WRITE;
/*!40000 ALTER TABLE `POLICY_CONFIG` DISABLE KEYS */;
/*!40000 ALTER TABLE `POLICY_CONFIG` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `PROTOCOL_MAPPER`
--

DROP TABLE IF EXISTS `PROTOCOL_MAPPER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PROTOCOL_MAPPER` (
  `ID` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `PROTOCOL` varchar(255) NOT NULL,
  `PROTOCOL_MAPPER_NAME` varchar(255) NOT NULL,
  `CLIENT_ID` varchar(36) DEFAULT NULL,
  `CLIENT_SCOPE_ID` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_PROTOCOL_MAPPER_CLIENT` (`CLIENT_ID`),
  KEY `IDX_CLSCOPE_PROTMAP` (`CLIENT_SCOPE_ID`),
  CONSTRAINT `FK_CLI_SCOPE_MAPPER` FOREIGN KEY (`CLIENT_SCOPE_ID`) REFERENCES `CLIENT_SCOPE` (`ID`),
  CONSTRAINT `FK_PCM_REALM` FOREIGN KEY (`CLIENT_ID`) REFERENCES `CLIENT` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `PROTOCOL_MAPPER`
--

LOCK TABLES `PROTOCOL_MAPPER` WRITE;
/*!40000 ALTER TABLE `PROTOCOL_MAPPER` DISABLE KEYS */;
INSERT INTO `PROTOCOL_MAPPER` VALUES
('0170b38b-0f3e-4f7a-bfed-bc1e7b277ec5','audience resolve','openid-connect','oidc-audience-resolve-mapper',NULL,'92fb03e0-4c6d-4b25-ac33-54ace6e61139'),
('05e43605-1f1a-42fd-81b4-de665a2d805c','website','openid-connect','oidc-usermodel-attribute-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('09addf80-220d-41c2-9571-efe077cd8fce','client roles','openid-connect','oidc-usermodel-client-role-mapper',NULL,'608e02cb-3f63-4e89-9258-fbd1c7c6d8f0'),
('0b600d50-dc43-40ec-b590-9961090a4195','nickname','openid-connect','oidc-usermodel-attribute-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('0c3bf7c0-aa98-46b1-ac18-8c867e3ffb7e','zoneinfo','openid-connect','oidc-usermodel-attribute-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('0c722fc6-0797-4483-a157-db9b91030799','phone number','openid-connect','oidc-usermodel-attribute-mapper',NULL,'a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c'),
('11ee5d41-1aa6-446a-8004-e43b719895c4','full name','openid-connect','oidc-full-name-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('13c76ae7-ba18-419e-b045-1986c216d9a1','given name','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('13fcb287-43b8-4681-8d7b-012b8aead621','phone number verified','openid-connect','oidc-usermodel-attribute-mapper',NULL,'a7beabe5-4cbf-421b-bd0b-f0d4e5ae2a8c'),
('14a1a31c-a5b1-47a7-9618-a70446d35482','realm roles','openid-connect','oidc-usermodel-realm-role-mapper',NULL,'608e02cb-3f63-4e89-9258-fbd1c7c6d8f0'),
('1858a4a7-bf03-4136-9e76-17dc878bb291','realm roles','openid-connect','oidc-usermodel-realm-role-mapper',NULL,'92fb03e0-4c6d-4b25-ac33-54ace6e61139'),
('1e0e1463-c039-4dbc-ac3b-73a307659b3a','picture','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('234e0759-7938-4ad7-a392-18a682926a59','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','c4e639d7-8646-4f98-a9ba-c66d912ea13b',NULL),
('26311482-3942-493e-b715-7f5eda12c6f9','acr loa level','openid-connect','oidc-acr-mapper',NULL,'5e701f0b-2581-4458-a171-fdf2aa34d1c9'),
('26dd3acb-8b90-4851-a3bb-41a035d978f6','address','openid-connect','oidc-address-mapper',NULL,'cecca841-4cd1-4f09-8724-fa20c73281b8'),
('2bcc0162-5c7b-4060-b7de-70eb4bcfee95','phone number','openid-connect','oidc-usermodel-attribute-mapper',NULL,'c47be204-f074-4670-8bd3-fd526ef41655'),
('2e4d19a6-c0d8-4f53-a673-09d44d439116','Client Host','openid-connect','oidc-usersessionmodel-note-mapper','c4e639d7-8646-4f98-a9ba-c66d912ea13b',NULL),
('2e502be4-c90a-4536-9524-c575fb6a5359','groups','openid-connect','oidc-usermodel-realm-role-mapper',NULL,'4277aaef-8983-44c7-81c6-d3c3485aa3fa'),
('31778269-bade-4bb0-b605-edcbdcb85941','birthdate','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('32288a0b-e405-4b74-a865-b42c41c33834','username','openid-connect','oidc-usermodel-property-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('33c5e866-ccce-46e9-b3ae-922e9d96476d','allowed web origins','openid-connect','oidc-allowed-origins-mapper',NULL,'7e7ae27c-e4d0-44e2-9e14-5e3bb88cb706'),
('374a3de4-23ab-4b9d-9af0-0c789488bf1c','full name','openid-connect','oidc-full-name-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('37e0c888-2482-45d2-9ff0-6a72777bed5f','address','openid-connect','oidc-address-mapper',NULL,'e5c89cef-3d47-4a27-882c-9cd6cb52d7ff'),
('3bc2112c-743d-48ff-9685-785d33f6b23f','updated at','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('45ea0491-50a3-4a03-963f-985e9485ea52','role list','saml','saml-role-list-mapper',NULL,'e3f1e796-a25e-4e58-a07d-5362a6d0139c'),
('489a71db-492b-45bc-a789-5c414efabe68','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','cf784c13-493e-4d43-86ee-8b9c81845b12',NULL),
('4bf6bf67-0e3a-4b33-b0e9-bbfad0b7b892','email','openid-connect','oidc-usermodel-property-mapper',NULL,'32ad3d0c-d877-4811-bcfd-474b40ad1e8d'),
('4e0143f4-676e-4951-8111-a536b1a042fd','middle name','openid-connect','oidc-usermodel-attribute-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('527cfc27-e59c-45af-8cd2-127a8feff220','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','99663a99-9477-4699-a933-e91d41961578',NULL),
('56fd358c-9fa4-4321-88bd-18b463373bb1','locale','openid-connect','oidc-usermodel-attribute-mapper','69b3d96b-db94-4825-b7be-95919a24d55a',NULL),
('5928a7a3-69a3-42fa-aa36-b46bd1bbf960','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','5783ae22-22b9-411d-a1c5-358b4e5b08a4',NULL),
('59789a21-7810-451f-9d16-c5826a59a393','birthdate','openid-connect','oidc-usermodel-attribute-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('5f9d22c3-10c4-4fac-8659-8dbdc11f92b7','acr loa level','openid-connect','oidc-acr-mapper',NULL,'f777a7aa-288e-4dfa-9fc5-7ab27e6f01d9'),
('66f909fa-fb5d-4b95-8330-0fbed41c14f2','allowed web origins','openid-connect','oidc-allowed-origins-mapper',NULL,'e3c658f5-9390-4b8d-a333-062a54a65ba5'),
('71cc8774-cb1c-46bf-b45f-c80783914480','updated at','openid-connect','oidc-usermodel-attribute-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('74ca66f6-05d1-42fe-a869-62bddc431fad','family name','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('784aa1fd-4f77-4695-96b1-20bc9605917c','upn','openid-connect','oidc-usermodel-property-mapper',NULL,'4277aaef-8983-44c7-81c6-d3c3485aa3fa'),
('79ad1664-24af-4ddd-8e2b-139f7c0ca1d5','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','0e283c44-f7e1-407a-b5ad-7593a14aa8db',NULL),
('7a76acaf-c8ab-4c7f-b114-a703ae053d56','profile','openid-connect','oidc-usermodel-attribute-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('7afaaa19-301f-43bf-8a2c-12ee30427d15','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','318c3a27-e2db-4c7c-90c6-d08edb13e055',NULL),
('7bec533c-eaf1-4ad1-a8a8-62710100a3c6','nickname','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('7da27a5d-949b-4d72-ae3f-76de862187eb','audience resolve','openid-connect','oidc-audience-resolve-mapper',NULL,'608e02cb-3f63-4e89-9258-fbd1c7c6d8f0'),
('83e9936f-e55f-48a9-8dce-11437d784fdf','email verified','openid-connect','oidc-usermodel-property-mapper',NULL,'32ad3d0c-d877-4811-bcfd-474b40ad1e8d'),
('85426bb4-9190-4748-8e92-4d4ad7394b2f','locale','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('899c5e1d-716e-48eb-8ae6-cee4e4e0ef5f','picture','openid-connect','oidc-usermodel-attribute-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('905afd79-f74a-4936-ae10-9129f4a831a1','groups','openid-connect','oidc-usermodel-realm-role-mapper',NULL,'7538c9cb-f57d-4358-a073-1eb9bcbe0f29'),
('91a77f92-7ea8-4230-bed0-0f4189263932','Client ID','openid-connect','oidc-usersessionmodel-note-mapper','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('96152040-0f64-4f86-af5f-7c4948dfefc8','phone number verified','openid-connect','oidc-usermodel-attribute-mapper',NULL,'c47be204-f074-4670-8bd3-fd526ef41655'),
('970ff80c-8bc2-4475-9873-d6b2eb1b41d0','profile','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('9d80f76f-7b15-4f53-b810-b79f698e2e2b','middle name','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('9ec54240-1e66-4218-8bc9-4bcd725752c7','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','734008f7-c43e-46e5-8ca8-1cefd1177608',NULL),
('9fa55028-25c6-4ac4-84d6-25941d5d0931','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('a07e0780-fd68-455d-9f92-7ddca1437cbf','locale','openid-connect','oidc-usermodel-attribute-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('aa4ee945-feed-41ec-a692-b34cfb1e893e','Client IP Address','openid-connect','oidc-usersessionmodel-note-mapper','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('ab7dfc7c-6fa1-4fb8-8b43-0256c763f267','family name','openid-connect','oidc-usermodel-property-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('ac6f453b-bb2e-4227-ab30-c59f3392c0df','website','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('b491bc10-cf8e-4e0e-bc5e-63dafb854627','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','21f67541-6b75-4f76-92e5-a2b7aa97937b',NULL),
('bb572f08-43b7-4e0b-9895-5dc16c7c4fed','Client ID','openid-connect','oidc-usersessionmodel-note-mapper','c4e639d7-8646-4f98-a9ba-c66d912ea13b',NULL),
('c5fbf67a-8096-4702-b800-513cc7fc1c2d','audience resolve','openid-connect','oidc-audience-resolve-mapper','99663a99-9477-4699-a933-e91d41961578',NULL),
('c8cd5ee9-c411-4990-9b09-fd0e4ad8a01c','gender','openid-connect','oidc-usermodel-attribute-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('d0cbe0b0-5c53-4488-8edf-d08e2bf75586','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','a6f6cb61-4f2a-4932-a629-b58e25de88ca',NULL),
('d111c070-206d-47f5-8065-67a97f9693d7','email','openid-connect','oidc-usermodel-attribute-mapper',NULL,'564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d'),
('d2c449d1-b201-4be4-ac7f-f9ff40d1729a','audience resolve','openid-connect','oidc-audience-resolve-mapper','b2438863-f1f8-49f9-bc6b-e696f83a1aab',NULL),
('d3e4b7ca-599c-4bc9-81dd-8b3912986ac5','client roles','openid-connect','oidc-usermodel-client-role-mapper',NULL,'92fb03e0-4c6d-4b25-ac33-54ace6e61139'),
('d616b31d-34c1-4304-9eb3-80030ec7de75','Client IP Address','openid-connect','oidc-usersessionmodel-note-mapper','c4e639d7-8646-4f98-a9ba-c66d912ea13b',NULL),
('d99eb2b2-464a-40c4-8846-5dab8d83bf88','locale','openid-connect','oidc-usermodel-attribute-mapper','0e283c44-f7e1-407a-b5ad-7593a14aa8db',NULL),
('dedfe7cf-9a03-4d54-8447-bcdf2aa6ef99','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','69b3d96b-db94-4825-b7be-95919a24d55a',NULL),
('e32f2a20-b8cb-4fcb-b432-fa8697ea729d','username','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('eac21d37-7e1d-4aba-b98c-6db4ddf80ffb','zoneinfo','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a'),
('ec9b6524-88af-47a5-aa55-0aff5561ee27','given name','openid-connect','oidc-usermodel-property-mapper',NULL,'980ab3c2-627a-4b0f-82fe-3e9216cdda7f'),
('ed180118-009d-4edd-b2bd-21dff36f933b','Client Host','openid-connect','oidc-usersessionmodel-note-mapper','a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('f395726f-5f88-4775-992e-e6614efee7a6','role list','saml','saml-role-list-mapper',NULL,'36f24f6c-f32a-4537-977b-dff0b0de9470'),
('f5306d48-2b74-46be-8377-0a15b58831fb','upn','openid-connect','oidc-usermodel-attribute-mapper',NULL,'7538c9cb-f57d-4358-a073-1eb9bcbe0f29'),
('f5b6a37c-79b2-475e-a1e4-c31159333b1e','docker-v2-allow-all-mapper','docker-v2','docker-v2-allow-all-mapper','b2438863-f1f8-49f9-bc6b-e696f83a1aab',NULL),
('fa59c391-9465-4724-9cad-a1c04f9901f4','email verified','openid-connect','oidc-usermodel-property-mapper',NULL,'564d3f68-4d7e-4ff0-a1d5-8ffce7219f1d'),
('fed3559a-1907-4af5-8bcb-e591a2f56e18','gender','openid-connect','oidc-usermodel-attribute-mapper',NULL,'b9130729-e811-4118-9c3c-2fe95a93bd5a');
/*!40000 ALTER TABLE `PROTOCOL_MAPPER` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `PROTOCOL_MAPPER_CONFIG`
--

DROP TABLE IF EXISTS `PROTOCOL_MAPPER_CONFIG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PROTOCOL_MAPPER_CONFIG` (
  `PROTOCOL_MAPPER_ID` varchar(36) NOT NULL,
  `VALUE` longtext DEFAULT NULL,
  `NAME` varchar(255) NOT NULL,
  PRIMARY KEY (`PROTOCOL_MAPPER_ID`,`NAME`),
  CONSTRAINT `FK_PMCONFIG` FOREIGN KEY (`PROTOCOL_MAPPER_ID`) REFERENCES `PROTOCOL_MAPPER` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `PROTOCOL_MAPPER_CONFIG`
--

LOCK TABLES `PROTOCOL_MAPPER_CONFIG` WRITE;
/*!40000 ALTER TABLE `PROTOCOL_MAPPER_CONFIG` DISABLE KEYS */;
INSERT INTO `PROTOCOL_MAPPER_CONFIG` VALUES
('0170b38b-0f3e-4f7a-bfed-bc1e7b277ec5','true','access.token.claim'),
('0170b38b-0f3e-4f7a-bfed-bc1e7b277ec5','true','introspection.token.claim'),
('05e43605-1f1a-42fd-81b4-de665a2d805c','true','access.token.claim'),
('05e43605-1f1a-42fd-81b4-de665a2d805c','website','claim.name'),
('05e43605-1f1a-42fd-81b4-de665a2d805c','true','id.token.claim'),
('05e43605-1f1a-42fd-81b4-de665a2d805c','String','jsonType.label'),
('05e43605-1f1a-42fd-81b4-de665a2d805c','website','user.attribute'),
('05e43605-1f1a-42fd-81b4-de665a2d805c','true','userinfo.token.claim'),
('09addf80-220d-41c2-9571-efe077cd8fce','true','access.token.claim'),
('09addf80-220d-41c2-9571-efe077cd8fce','resource_access.${client_id}.roles','claim.name'),
('09addf80-220d-41c2-9571-efe077cd8fce','String','jsonType.label'),
('09addf80-220d-41c2-9571-efe077cd8fce','true','multivalued'),
('09addf80-220d-41c2-9571-efe077cd8fce','foo','user.attribute'),
('0b600d50-dc43-40ec-b590-9961090a4195','true','access.token.claim'),
('0b600d50-dc43-40ec-b590-9961090a4195','nickname','claim.name'),
('0b600d50-dc43-40ec-b590-9961090a4195','true','id.token.claim'),
('0b600d50-dc43-40ec-b590-9961090a4195','String','jsonType.label'),
('0b600d50-dc43-40ec-b590-9961090a4195','nickname','user.attribute'),
('0b600d50-dc43-40ec-b590-9961090a4195','true','userinfo.token.claim'),
('0c3bf7c0-aa98-46b1-ac18-8c867e3ffb7e','true','access.token.claim'),
('0c3bf7c0-aa98-46b1-ac18-8c867e3ffb7e','zoneinfo','claim.name'),
('0c3bf7c0-aa98-46b1-ac18-8c867e3ffb7e','true','id.token.claim'),
('0c3bf7c0-aa98-46b1-ac18-8c867e3ffb7e','String','jsonType.label'),
('0c3bf7c0-aa98-46b1-ac18-8c867e3ffb7e','zoneinfo','user.attribute'),
('0c3bf7c0-aa98-46b1-ac18-8c867e3ffb7e','true','userinfo.token.claim'),
('0c722fc6-0797-4483-a157-db9b91030799','true','access.token.claim'),
('0c722fc6-0797-4483-a157-db9b91030799','phone_number','claim.name'),
('0c722fc6-0797-4483-a157-db9b91030799','true','id.token.claim'),
('0c722fc6-0797-4483-a157-db9b91030799','String','jsonType.label'),
('0c722fc6-0797-4483-a157-db9b91030799','phoneNumber','user.attribute'),
('0c722fc6-0797-4483-a157-db9b91030799','true','userinfo.token.claim'),
('11ee5d41-1aa6-446a-8004-e43b719895c4','true','access.token.claim'),
('11ee5d41-1aa6-446a-8004-e43b719895c4','true','id.token.claim'),
('11ee5d41-1aa6-446a-8004-e43b719895c4','true','introspection.token.claim'),
('11ee5d41-1aa6-446a-8004-e43b719895c4','true','userinfo.token.claim'),
('13c76ae7-ba18-419e-b045-1986c216d9a1','true','access.token.claim'),
('13c76ae7-ba18-419e-b045-1986c216d9a1','given_name','claim.name'),
('13c76ae7-ba18-419e-b045-1986c216d9a1','true','id.token.claim'),
('13c76ae7-ba18-419e-b045-1986c216d9a1','true','introspection.token.claim'),
('13c76ae7-ba18-419e-b045-1986c216d9a1','String','jsonType.label'),
('13c76ae7-ba18-419e-b045-1986c216d9a1','firstName','user.attribute'),
('13c76ae7-ba18-419e-b045-1986c216d9a1','true','userinfo.token.claim'),
('13fcb287-43b8-4681-8d7b-012b8aead621','true','access.token.claim'),
('13fcb287-43b8-4681-8d7b-012b8aead621','phone_number_verified','claim.name'),
('13fcb287-43b8-4681-8d7b-012b8aead621','true','id.token.claim'),
('13fcb287-43b8-4681-8d7b-012b8aead621','boolean','jsonType.label'),
('13fcb287-43b8-4681-8d7b-012b8aead621','phoneNumberVerified','user.attribute'),
('13fcb287-43b8-4681-8d7b-012b8aead621','true','userinfo.token.claim'),
('14a1a31c-a5b1-47a7-9618-a70446d35482','true','access.token.claim'),
('14a1a31c-a5b1-47a7-9618-a70446d35482','realm_access.roles','claim.name'),
('14a1a31c-a5b1-47a7-9618-a70446d35482','String','jsonType.label'),
('14a1a31c-a5b1-47a7-9618-a70446d35482','true','multivalued'),
('14a1a31c-a5b1-47a7-9618-a70446d35482','foo','user.attribute'),
('1858a4a7-bf03-4136-9e76-17dc878bb291','true','access.token.claim'),
('1858a4a7-bf03-4136-9e76-17dc878bb291','realm_access.roles','claim.name'),
('1858a4a7-bf03-4136-9e76-17dc878bb291','true','introspection.token.claim'),
('1858a4a7-bf03-4136-9e76-17dc878bb291','String','jsonType.label'),
('1858a4a7-bf03-4136-9e76-17dc878bb291','true','multivalued'),
('1858a4a7-bf03-4136-9e76-17dc878bb291','foo','user.attribute'),
('1e0e1463-c039-4dbc-ac3b-73a307659b3a','true','access.token.claim'),
('1e0e1463-c039-4dbc-ac3b-73a307659b3a','picture','claim.name'),
('1e0e1463-c039-4dbc-ac3b-73a307659b3a','true','id.token.claim'),
('1e0e1463-c039-4dbc-ac3b-73a307659b3a','true','introspection.token.claim'),
('1e0e1463-c039-4dbc-ac3b-73a307659b3a','String','jsonType.label'),
('1e0e1463-c039-4dbc-ac3b-73a307659b3a','picture','user.attribute'),
('1e0e1463-c039-4dbc-ac3b-73a307659b3a','true','userinfo.token.claim'),
('26311482-3942-493e-b715-7f5eda12c6f9','true','access.token.claim'),
('26311482-3942-493e-b715-7f5eda12c6f9','true','id.token.claim'),
('26311482-3942-493e-b715-7f5eda12c6f9','true','introspection.token.claim'),
('26dd3acb-8b90-4851-a3bb-41a035d978f6','true','access.token.claim'),
('26dd3acb-8b90-4851-a3bb-41a035d978f6','true','id.token.claim'),
('26dd3acb-8b90-4851-a3bb-41a035d978f6','country','user.attribute.country'),
('26dd3acb-8b90-4851-a3bb-41a035d978f6','formatted','user.attribute.formatted'),
('26dd3acb-8b90-4851-a3bb-41a035d978f6','locality','user.attribute.locality'),
('26dd3acb-8b90-4851-a3bb-41a035d978f6','postal_code','user.attribute.postal_code'),
('26dd3acb-8b90-4851-a3bb-41a035d978f6','region','user.attribute.region'),
('26dd3acb-8b90-4851-a3bb-41a035d978f6','street','user.attribute.street'),
('26dd3acb-8b90-4851-a3bb-41a035d978f6','true','userinfo.token.claim'),
('2bcc0162-5c7b-4060-b7de-70eb4bcfee95','true','access.token.claim'),
('2bcc0162-5c7b-4060-b7de-70eb4bcfee95','phone_number','claim.name'),
('2bcc0162-5c7b-4060-b7de-70eb4bcfee95','true','id.token.claim'),
('2bcc0162-5c7b-4060-b7de-70eb4bcfee95','true','introspection.token.claim'),
('2bcc0162-5c7b-4060-b7de-70eb4bcfee95','String','jsonType.label'),
('2bcc0162-5c7b-4060-b7de-70eb4bcfee95','phoneNumber','user.attribute'),
('2bcc0162-5c7b-4060-b7de-70eb4bcfee95','true','userinfo.token.claim'),
('2e4d19a6-c0d8-4f53-a673-09d44d439116','true','access.token.claim'),
('2e4d19a6-c0d8-4f53-a673-09d44d439116','clientHost','claim.name'),
('2e4d19a6-c0d8-4f53-a673-09d44d439116','true','id.token.claim'),
('2e4d19a6-c0d8-4f53-a673-09d44d439116','String','jsonType.label'),
('2e4d19a6-c0d8-4f53-a673-09d44d439116','clientHost','user.session.note'),
('2e4d19a6-c0d8-4f53-a673-09d44d439116','true','userinfo.token.claim'),
('2e502be4-c90a-4536-9524-c575fb6a5359','true','access.token.claim'),
('2e502be4-c90a-4536-9524-c575fb6a5359','groups','claim.name'),
('2e502be4-c90a-4536-9524-c575fb6a5359','true','id.token.claim'),
('2e502be4-c90a-4536-9524-c575fb6a5359','String','jsonType.label'),
('2e502be4-c90a-4536-9524-c575fb6a5359','true','multivalued'),
('2e502be4-c90a-4536-9524-c575fb6a5359','foo','user.attribute'),
('2e502be4-c90a-4536-9524-c575fb6a5359','true','userinfo.token.claim'),
('31778269-bade-4bb0-b605-edcbdcb85941','true','access.token.claim'),
('31778269-bade-4bb0-b605-edcbdcb85941','birthdate','claim.name'),
('31778269-bade-4bb0-b605-edcbdcb85941','true','id.token.claim'),
('31778269-bade-4bb0-b605-edcbdcb85941','true','introspection.token.claim'),
('31778269-bade-4bb0-b605-edcbdcb85941','String','jsonType.label'),
('31778269-bade-4bb0-b605-edcbdcb85941','birthdate','user.attribute'),
('31778269-bade-4bb0-b605-edcbdcb85941','true','userinfo.token.claim'),
('32288a0b-e405-4b74-a865-b42c41c33834','true','access.token.claim'),
('32288a0b-e405-4b74-a865-b42c41c33834','preferred_username','claim.name'),
('32288a0b-e405-4b74-a865-b42c41c33834','true','id.token.claim'),
('32288a0b-e405-4b74-a865-b42c41c33834','String','jsonType.label'),
('32288a0b-e405-4b74-a865-b42c41c33834','username','user.attribute'),
('32288a0b-e405-4b74-a865-b42c41c33834','true','userinfo.token.claim'),
('374a3de4-23ab-4b9d-9af0-0c789488bf1c','true','access.token.claim'),
('374a3de4-23ab-4b9d-9af0-0c789488bf1c','true','id.token.claim'),
('374a3de4-23ab-4b9d-9af0-0c789488bf1c','true','userinfo.token.claim'),
('37e0c888-2482-45d2-9ff0-6a72777bed5f','true','access.token.claim'),
('37e0c888-2482-45d2-9ff0-6a72777bed5f','true','id.token.claim'),
('37e0c888-2482-45d2-9ff0-6a72777bed5f','true','introspection.token.claim'),
('37e0c888-2482-45d2-9ff0-6a72777bed5f','country','user.attribute.country'),
('37e0c888-2482-45d2-9ff0-6a72777bed5f','formatted','user.attribute.formatted'),
('37e0c888-2482-45d2-9ff0-6a72777bed5f','locality','user.attribute.locality'),
('37e0c888-2482-45d2-9ff0-6a72777bed5f','postal_code','user.attribute.postal_code'),
('37e0c888-2482-45d2-9ff0-6a72777bed5f','region','user.attribute.region'),
('37e0c888-2482-45d2-9ff0-6a72777bed5f','street','user.attribute.street'),
('37e0c888-2482-45d2-9ff0-6a72777bed5f','true','userinfo.token.claim'),
('3bc2112c-743d-48ff-9685-785d33f6b23f','true','access.token.claim'),
('3bc2112c-743d-48ff-9685-785d33f6b23f','updated_at','claim.name'),
('3bc2112c-743d-48ff-9685-785d33f6b23f','true','id.token.claim'),
('3bc2112c-743d-48ff-9685-785d33f6b23f','true','introspection.token.claim'),
('3bc2112c-743d-48ff-9685-785d33f6b23f','long','jsonType.label'),
('3bc2112c-743d-48ff-9685-785d33f6b23f','updatedAt','user.attribute'),
('3bc2112c-743d-48ff-9685-785d33f6b23f','true','userinfo.token.claim'),
('45ea0491-50a3-4a03-963f-985e9485ea52','Role','attribute.name'),
('45ea0491-50a3-4a03-963f-985e9485ea52','Basic','attribute.nameformat'),
('45ea0491-50a3-4a03-963f-985e9485ea52','false','single'),
('4bf6bf67-0e3a-4b33-b0e9-bbfad0b7b892','true','access.token.claim'),
('4bf6bf67-0e3a-4b33-b0e9-bbfad0b7b892','email','claim.name'),
('4bf6bf67-0e3a-4b33-b0e9-bbfad0b7b892','true','id.token.claim'),
('4bf6bf67-0e3a-4b33-b0e9-bbfad0b7b892','String','jsonType.label'),
('4bf6bf67-0e3a-4b33-b0e9-bbfad0b7b892','email','user.attribute'),
('4bf6bf67-0e3a-4b33-b0e9-bbfad0b7b892','true','userinfo.token.claim'),
('4e0143f4-676e-4951-8111-a536b1a042fd','true','access.token.claim'),
('4e0143f4-676e-4951-8111-a536b1a042fd','middle_name','claim.name'),
('4e0143f4-676e-4951-8111-a536b1a042fd','true','id.token.claim'),
('4e0143f4-676e-4951-8111-a536b1a042fd','String','jsonType.label'),
('4e0143f4-676e-4951-8111-a536b1a042fd','middleName','user.attribute'),
('4e0143f4-676e-4951-8111-a536b1a042fd','true','userinfo.token.claim'),
('56fd358c-9fa4-4321-88bd-18b463373bb1','true','access.token.claim'),
('56fd358c-9fa4-4321-88bd-18b463373bb1','locale','claim.name'),
('56fd358c-9fa4-4321-88bd-18b463373bb1','true','id.token.claim'),
('56fd358c-9fa4-4321-88bd-18b463373bb1','true','introspection.token.claim'),
('56fd358c-9fa4-4321-88bd-18b463373bb1','String','jsonType.label'),
('56fd358c-9fa4-4321-88bd-18b463373bb1','locale','user.attribute'),
('56fd358c-9fa4-4321-88bd-18b463373bb1','true','userinfo.token.claim'),
('59789a21-7810-451f-9d16-c5826a59a393','true','access.token.claim'),
('59789a21-7810-451f-9d16-c5826a59a393','birthdate','claim.name'),
('59789a21-7810-451f-9d16-c5826a59a393','true','id.token.claim'),
('59789a21-7810-451f-9d16-c5826a59a393','String','jsonType.label'),
('59789a21-7810-451f-9d16-c5826a59a393','birthdate','user.attribute'),
('59789a21-7810-451f-9d16-c5826a59a393','true','userinfo.token.claim'),
('5f9d22c3-10c4-4fac-8659-8dbdc11f92b7','true','access.token.claim'),
('5f9d22c3-10c4-4fac-8659-8dbdc11f92b7','true','id.token.claim'),
('5f9d22c3-10c4-4fac-8659-8dbdc11f92b7','true','userinfo.token.claim'),
('66f909fa-fb5d-4b95-8330-0fbed41c14f2','true','access.token.claim'),
('66f909fa-fb5d-4b95-8330-0fbed41c14f2','true','introspection.token.claim'),
('71cc8774-cb1c-46bf-b45f-c80783914480','true','access.token.claim'),
('71cc8774-cb1c-46bf-b45f-c80783914480','updated_at','claim.name'),
('71cc8774-cb1c-46bf-b45f-c80783914480','true','id.token.claim'),
('71cc8774-cb1c-46bf-b45f-c80783914480','long','jsonType.label'),
('71cc8774-cb1c-46bf-b45f-c80783914480','updatedAt','user.attribute'),
('71cc8774-cb1c-46bf-b45f-c80783914480','true','userinfo.token.claim'),
('74ca66f6-05d1-42fe-a869-62bddc431fad','true','access.token.claim'),
('74ca66f6-05d1-42fe-a869-62bddc431fad','family_name','claim.name'),
('74ca66f6-05d1-42fe-a869-62bddc431fad','true','id.token.claim'),
('74ca66f6-05d1-42fe-a869-62bddc431fad','true','introspection.token.claim'),
('74ca66f6-05d1-42fe-a869-62bddc431fad','String','jsonType.label'),
('74ca66f6-05d1-42fe-a869-62bddc431fad','lastName','user.attribute'),
('74ca66f6-05d1-42fe-a869-62bddc431fad','true','userinfo.token.claim'),
('784aa1fd-4f77-4695-96b1-20bc9605917c','true','access.token.claim'),
('784aa1fd-4f77-4695-96b1-20bc9605917c','upn','claim.name'),
('784aa1fd-4f77-4695-96b1-20bc9605917c','true','id.token.claim'),
('784aa1fd-4f77-4695-96b1-20bc9605917c','String','jsonType.label'),
('784aa1fd-4f77-4695-96b1-20bc9605917c','username','user.attribute'),
('784aa1fd-4f77-4695-96b1-20bc9605917c','true','userinfo.token.claim'),
('7a76acaf-c8ab-4c7f-b114-a703ae053d56','true','access.token.claim'),
('7a76acaf-c8ab-4c7f-b114-a703ae053d56','profile','claim.name'),
('7a76acaf-c8ab-4c7f-b114-a703ae053d56','true','id.token.claim'),
('7a76acaf-c8ab-4c7f-b114-a703ae053d56','String','jsonType.label'),
('7a76acaf-c8ab-4c7f-b114-a703ae053d56','profile','user.attribute'),
('7a76acaf-c8ab-4c7f-b114-a703ae053d56','true','userinfo.token.claim'),
('7bec533c-eaf1-4ad1-a8a8-62710100a3c6','true','access.token.claim'),
('7bec533c-eaf1-4ad1-a8a8-62710100a3c6','nickname','claim.name'),
('7bec533c-eaf1-4ad1-a8a8-62710100a3c6','true','id.token.claim'),
('7bec533c-eaf1-4ad1-a8a8-62710100a3c6','true','introspection.token.claim'),
('7bec533c-eaf1-4ad1-a8a8-62710100a3c6','String','jsonType.label'),
('7bec533c-eaf1-4ad1-a8a8-62710100a3c6','nickname','user.attribute'),
('7bec533c-eaf1-4ad1-a8a8-62710100a3c6','true','userinfo.token.claim'),
('83e9936f-e55f-48a9-8dce-11437d784fdf','true','access.token.claim'),
('83e9936f-e55f-48a9-8dce-11437d784fdf','email_verified','claim.name'),
('83e9936f-e55f-48a9-8dce-11437d784fdf','true','id.token.claim'),
('83e9936f-e55f-48a9-8dce-11437d784fdf','boolean','jsonType.label'),
('83e9936f-e55f-48a9-8dce-11437d784fdf','emailVerified','user.attribute'),
('83e9936f-e55f-48a9-8dce-11437d784fdf','true','userinfo.token.claim'),
('85426bb4-9190-4748-8e92-4d4ad7394b2f','true','access.token.claim'),
('85426bb4-9190-4748-8e92-4d4ad7394b2f','locale','claim.name'),
('85426bb4-9190-4748-8e92-4d4ad7394b2f','true','id.token.claim'),
('85426bb4-9190-4748-8e92-4d4ad7394b2f','true','introspection.token.claim'),
('85426bb4-9190-4748-8e92-4d4ad7394b2f','String','jsonType.label'),
('85426bb4-9190-4748-8e92-4d4ad7394b2f','locale','user.attribute'),
('85426bb4-9190-4748-8e92-4d4ad7394b2f','true','userinfo.token.claim'),
('899c5e1d-716e-48eb-8ae6-cee4e4e0ef5f','true','access.token.claim'),
('899c5e1d-716e-48eb-8ae6-cee4e4e0ef5f','picture','claim.name'),
('899c5e1d-716e-48eb-8ae6-cee4e4e0ef5f','true','id.token.claim'),
('899c5e1d-716e-48eb-8ae6-cee4e4e0ef5f','String','jsonType.label'),
('899c5e1d-716e-48eb-8ae6-cee4e4e0ef5f','picture','user.attribute'),
('899c5e1d-716e-48eb-8ae6-cee4e4e0ef5f','true','userinfo.token.claim'),
('905afd79-f74a-4936-ae10-9129f4a831a1','true','access.token.claim'),
('905afd79-f74a-4936-ae10-9129f4a831a1','groups','claim.name'),
('905afd79-f74a-4936-ae10-9129f4a831a1','true','id.token.claim'),
('905afd79-f74a-4936-ae10-9129f4a831a1','true','introspection.token.claim'),
('905afd79-f74a-4936-ae10-9129f4a831a1','String','jsonType.label'),
('905afd79-f74a-4936-ae10-9129f4a831a1','true','multivalued'),
('905afd79-f74a-4936-ae10-9129f4a831a1','foo','user.attribute'),
('91a77f92-7ea8-4230-bed0-0f4189263932','true','access.token.claim'),
('91a77f92-7ea8-4230-bed0-0f4189263932','clientId','claim.name'),
('91a77f92-7ea8-4230-bed0-0f4189263932','true','id.token.claim'),
('91a77f92-7ea8-4230-bed0-0f4189263932','String','jsonType.label'),
('91a77f92-7ea8-4230-bed0-0f4189263932','clientId','user.session.note'),
('91a77f92-7ea8-4230-bed0-0f4189263932','true','userinfo.token.claim'),
('96152040-0f64-4f86-af5f-7c4948dfefc8','true','access.token.claim'),
('96152040-0f64-4f86-af5f-7c4948dfefc8','phone_number_verified','claim.name'),
('96152040-0f64-4f86-af5f-7c4948dfefc8','true','id.token.claim'),
('96152040-0f64-4f86-af5f-7c4948dfefc8','true','introspection.token.claim'),
('96152040-0f64-4f86-af5f-7c4948dfefc8','boolean','jsonType.label'),
('96152040-0f64-4f86-af5f-7c4948dfefc8','phoneNumberVerified','user.attribute'),
('96152040-0f64-4f86-af5f-7c4948dfefc8','true','userinfo.token.claim'),
('970ff80c-8bc2-4475-9873-d6b2eb1b41d0','true','access.token.claim'),
('970ff80c-8bc2-4475-9873-d6b2eb1b41d0','profile','claim.name'),
('970ff80c-8bc2-4475-9873-d6b2eb1b41d0','true','id.token.claim'),
('970ff80c-8bc2-4475-9873-d6b2eb1b41d0','true','introspection.token.claim'),
('970ff80c-8bc2-4475-9873-d6b2eb1b41d0','String','jsonType.label'),
('970ff80c-8bc2-4475-9873-d6b2eb1b41d0','profile','user.attribute'),
('970ff80c-8bc2-4475-9873-d6b2eb1b41d0','true','userinfo.token.claim'),
('9d80f76f-7b15-4f53-b810-b79f698e2e2b','true','access.token.claim'),
('9d80f76f-7b15-4f53-b810-b79f698e2e2b','middle_name','claim.name'),
('9d80f76f-7b15-4f53-b810-b79f698e2e2b','true','id.token.claim'),
('9d80f76f-7b15-4f53-b810-b79f698e2e2b','true','introspection.token.claim'),
('9d80f76f-7b15-4f53-b810-b79f698e2e2b','String','jsonType.label'),
('9d80f76f-7b15-4f53-b810-b79f698e2e2b','middleName','user.attribute'),
('9d80f76f-7b15-4f53-b810-b79f698e2e2b','true','userinfo.token.claim'),
('a07e0780-fd68-455d-9f92-7ddca1437cbf','true','access.token.claim'),
('a07e0780-fd68-455d-9f92-7ddca1437cbf','locale','claim.name'),
('a07e0780-fd68-455d-9f92-7ddca1437cbf','true','id.token.claim'),
('a07e0780-fd68-455d-9f92-7ddca1437cbf','String','jsonType.label'),
('a07e0780-fd68-455d-9f92-7ddca1437cbf','locale','user.attribute'),
('a07e0780-fd68-455d-9f92-7ddca1437cbf','true','userinfo.token.claim'),
('aa4ee945-feed-41ec-a692-b34cfb1e893e','true','access.token.claim'),
('aa4ee945-feed-41ec-a692-b34cfb1e893e','clientAddress','claim.name'),
('aa4ee945-feed-41ec-a692-b34cfb1e893e','true','id.token.claim'),
('aa4ee945-feed-41ec-a692-b34cfb1e893e','String','jsonType.label'),
('aa4ee945-feed-41ec-a692-b34cfb1e893e','clientAddress','user.session.note'),
('aa4ee945-feed-41ec-a692-b34cfb1e893e','true','userinfo.token.claim'),
('ab7dfc7c-6fa1-4fb8-8b43-0256c763f267','true','access.token.claim'),
('ab7dfc7c-6fa1-4fb8-8b43-0256c763f267','family_name','claim.name'),
('ab7dfc7c-6fa1-4fb8-8b43-0256c763f267','true','id.token.claim'),
('ab7dfc7c-6fa1-4fb8-8b43-0256c763f267','String','jsonType.label'),
('ab7dfc7c-6fa1-4fb8-8b43-0256c763f267','lastName','user.attribute'),
('ab7dfc7c-6fa1-4fb8-8b43-0256c763f267','true','userinfo.token.claim'),
('ac6f453b-bb2e-4227-ab30-c59f3392c0df','true','access.token.claim'),
('ac6f453b-bb2e-4227-ab30-c59f3392c0df','website','claim.name'),
('ac6f453b-bb2e-4227-ab30-c59f3392c0df','true','id.token.claim'),
('ac6f453b-bb2e-4227-ab30-c59f3392c0df','true','introspection.token.claim'),
('ac6f453b-bb2e-4227-ab30-c59f3392c0df','String','jsonType.label'),
('ac6f453b-bb2e-4227-ab30-c59f3392c0df','website','user.attribute'),
('ac6f453b-bb2e-4227-ab30-c59f3392c0df','true','userinfo.token.claim'),
('bb572f08-43b7-4e0b-9895-5dc16c7c4fed','true','access.token.claim'),
('bb572f08-43b7-4e0b-9895-5dc16c7c4fed','clientId','claim.name'),
('bb572f08-43b7-4e0b-9895-5dc16c7c4fed','true','id.token.claim'),
('bb572f08-43b7-4e0b-9895-5dc16c7c4fed','String','jsonType.label'),
('bb572f08-43b7-4e0b-9895-5dc16c7c4fed','clientId','user.session.note'),
('bb572f08-43b7-4e0b-9895-5dc16c7c4fed','true','userinfo.token.claim'),
('c8cd5ee9-c411-4990-9b09-fd0e4ad8a01c','true','access.token.claim'),
('c8cd5ee9-c411-4990-9b09-fd0e4ad8a01c','gender','claim.name'),
('c8cd5ee9-c411-4990-9b09-fd0e4ad8a01c','true','id.token.claim'),
('c8cd5ee9-c411-4990-9b09-fd0e4ad8a01c','String','jsonType.label'),
('c8cd5ee9-c411-4990-9b09-fd0e4ad8a01c','gender','user.attribute'),
('c8cd5ee9-c411-4990-9b09-fd0e4ad8a01c','true','userinfo.token.claim'),
('d111c070-206d-47f5-8065-67a97f9693d7','true','access.token.claim'),
('d111c070-206d-47f5-8065-67a97f9693d7','email','claim.name'),
('d111c070-206d-47f5-8065-67a97f9693d7','true','id.token.claim'),
('d111c070-206d-47f5-8065-67a97f9693d7','true','introspection.token.claim'),
('d111c070-206d-47f5-8065-67a97f9693d7','String','jsonType.label'),
('d111c070-206d-47f5-8065-67a97f9693d7','email','user.attribute'),
('d111c070-206d-47f5-8065-67a97f9693d7','true','userinfo.token.claim'),
('d3e4b7ca-599c-4bc9-81dd-8b3912986ac5','true','access.token.claim'),
('d3e4b7ca-599c-4bc9-81dd-8b3912986ac5','resource_access.${client_id}.roles','claim.name'),
('d3e4b7ca-599c-4bc9-81dd-8b3912986ac5','true','introspection.token.claim'),
('d3e4b7ca-599c-4bc9-81dd-8b3912986ac5','String','jsonType.label'),
('d3e4b7ca-599c-4bc9-81dd-8b3912986ac5','true','multivalued'),
('d3e4b7ca-599c-4bc9-81dd-8b3912986ac5','foo','user.attribute'),
('d616b31d-34c1-4304-9eb3-80030ec7de75','true','access.token.claim'),
('d616b31d-34c1-4304-9eb3-80030ec7de75','clientAddress','claim.name'),
('d616b31d-34c1-4304-9eb3-80030ec7de75','true','id.token.claim'),
('d616b31d-34c1-4304-9eb3-80030ec7de75','String','jsonType.label'),
('d616b31d-34c1-4304-9eb3-80030ec7de75','clientAddress','user.session.note'),
('d616b31d-34c1-4304-9eb3-80030ec7de75','true','userinfo.token.claim'),
('d99eb2b2-464a-40c4-8846-5dab8d83bf88','true','access.token.claim'),
('d99eb2b2-464a-40c4-8846-5dab8d83bf88','locale','claim.name'),
('d99eb2b2-464a-40c4-8846-5dab8d83bf88','true','id.token.claim'),
('d99eb2b2-464a-40c4-8846-5dab8d83bf88','String','jsonType.label'),
('d99eb2b2-464a-40c4-8846-5dab8d83bf88','locale','user.attribute'),
('d99eb2b2-464a-40c4-8846-5dab8d83bf88','true','userinfo.token.claim'),
('e32f2a20-b8cb-4fcb-b432-fa8697ea729d','true','access.token.claim'),
('e32f2a20-b8cb-4fcb-b432-fa8697ea729d','preferred_username','claim.name'),
('e32f2a20-b8cb-4fcb-b432-fa8697ea729d','true','id.token.claim'),
('e32f2a20-b8cb-4fcb-b432-fa8697ea729d','true','introspection.token.claim'),
('e32f2a20-b8cb-4fcb-b432-fa8697ea729d','String','jsonType.label'),
('e32f2a20-b8cb-4fcb-b432-fa8697ea729d','username','user.attribute'),
('e32f2a20-b8cb-4fcb-b432-fa8697ea729d','true','userinfo.token.claim'),
('eac21d37-7e1d-4aba-b98c-6db4ddf80ffb','true','access.token.claim'),
('eac21d37-7e1d-4aba-b98c-6db4ddf80ffb','zoneinfo','claim.name'),
('eac21d37-7e1d-4aba-b98c-6db4ddf80ffb','true','id.token.claim'),
('eac21d37-7e1d-4aba-b98c-6db4ddf80ffb','true','introspection.token.claim'),
('eac21d37-7e1d-4aba-b98c-6db4ddf80ffb','String','jsonType.label'),
('eac21d37-7e1d-4aba-b98c-6db4ddf80ffb','zoneinfo','user.attribute'),
('eac21d37-7e1d-4aba-b98c-6db4ddf80ffb','true','userinfo.token.claim'),
('ec9b6524-88af-47a5-aa55-0aff5561ee27','true','access.token.claim'),
('ec9b6524-88af-47a5-aa55-0aff5561ee27','given_name','claim.name'),
('ec9b6524-88af-47a5-aa55-0aff5561ee27','true','id.token.claim'),
('ec9b6524-88af-47a5-aa55-0aff5561ee27','String','jsonType.label'),
('ec9b6524-88af-47a5-aa55-0aff5561ee27','firstName','user.attribute'),
('ec9b6524-88af-47a5-aa55-0aff5561ee27','true','userinfo.token.claim'),
('ed180118-009d-4edd-b2bd-21dff36f933b','true','access.token.claim'),
('ed180118-009d-4edd-b2bd-21dff36f933b','clientHost','claim.name'),
('ed180118-009d-4edd-b2bd-21dff36f933b','true','id.token.claim'),
('ed180118-009d-4edd-b2bd-21dff36f933b','String','jsonType.label'),
('ed180118-009d-4edd-b2bd-21dff36f933b','clientHost','user.session.note'),
('ed180118-009d-4edd-b2bd-21dff36f933b','true','userinfo.token.claim'),
('f395726f-5f88-4775-992e-e6614efee7a6','Role','attribute.name'),
('f395726f-5f88-4775-992e-e6614efee7a6','Basic','attribute.nameformat'),
('f395726f-5f88-4775-992e-e6614efee7a6','false','single'),
('f5306d48-2b74-46be-8377-0a15b58831fb','true','access.token.claim'),
('f5306d48-2b74-46be-8377-0a15b58831fb','upn','claim.name'),
('f5306d48-2b74-46be-8377-0a15b58831fb','true','id.token.claim'),
('f5306d48-2b74-46be-8377-0a15b58831fb','true','introspection.token.claim'),
('f5306d48-2b74-46be-8377-0a15b58831fb','String','jsonType.label'),
('f5306d48-2b74-46be-8377-0a15b58831fb','username','user.attribute'),
('f5306d48-2b74-46be-8377-0a15b58831fb','true','userinfo.token.claim'),
('fa59c391-9465-4724-9cad-a1c04f9901f4','true','access.token.claim'),
('fa59c391-9465-4724-9cad-a1c04f9901f4','email_verified','claim.name'),
('fa59c391-9465-4724-9cad-a1c04f9901f4','true','id.token.claim'),
('fa59c391-9465-4724-9cad-a1c04f9901f4','true','introspection.token.claim'),
('fa59c391-9465-4724-9cad-a1c04f9901f4','boolean','jsonType.label'),
('fa59c391-9465-4724-9cad-a1c04f9901f4','emailVerified','user.attribute'),
('fa59c391-9465-4724-9cad-a1c04f9901f4','true','userinfo.token.claim'),
('fed3559a-1907-4af5-8bcb-e591a2f56e18','true','access.token.claim'),
('fed3559a-1907-4af5-8bcb-e591a2f56e18','gender','claim.name'),
('fed3559a-1907-4af5-8bcb-e591a2f56e18','true','id.token.claim'),
('fed3559a-1907-4af5-8bcb-e591a2f56e18','true','introspection.token.claim'),
('fed3559a-1907-4af5-8bcb-e591a2f56e18','String','jsonType.label'),
('fed3559a-1907-4af5-8bcb-e591a2f56e18','gender','user.attribute'),
('fed3559a-1907-4af5-8bcb-e591a2f56e18','true','userinfo.token.claim');
/*!40000 ALTER TABLE `PROTOCOL_MAPPER_CONFIG` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REALM`
--

DROP TABLE IF EXISTS `REALM`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REALM` (
  `ID` varchar(36) NOT NULL,
  `ACCESS_CODE_LIFESPAN` int(11) DEFAULT NULL,
  `USER_ACTION_LIFESPAN` int(11) DEFAULT NULL,
  `ACCESS_TOKEN_LIFESPAN` int(11) DEFAULT NULL,
  `ACCOUNT_THEME` varchar(255) DEFAULT NULL,
  `ADMIN_THEME` varchar(255) DEFAULT NULL,
  `EMAIL_THEME` varchar(255) DEFAULT NULL,
  `ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `EVENTS_ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `EVENTS_EXPIRATION` bigint(20) DEFAULT NULL,
  `LOGIN_THEME` varchar(255) DEFAULT NULL,
  `NAME` varchar(255) DEFAULT NULL,
  `NOT_BEFORE` int(11) DEFAULT NULL,
  `PASSWORD_POLICY` text DEFAULT NULL,
  `REGISTRATION_ALLOWED` bit(1) NOT NULL DEFAULT b'0',
  `REMEMBER_ME` bit(1) NOT NULL DEFAULT b'0',
  `RESET_PASSWORD_ALLOWED` bit(1) NOT NULL DEFAULT b'0',
  `SOCIAL` bit(1) NOT NULL DEFAULT b'0',
  `SSL_REQUIRED` varchar(255) DEFAULT NULL,
  `SSO_IDLE_TIMEOUT` int(11) DEFAULT NULL,
  `SSO_MAX_LIFESPAN` int(11) DEFAULT NULL,
  `UPDATE_PROFILE_ON_SOC_LOGIN` bit(1) NOT NULL DEFAULT b'0',
  `VERIFY_EMAIL` bit(1) NOT NULL DEFAULT b'0',
  `MASTER_ADMIN_CLIENT` varchar(36) DEFAULT NULL,
  `LOGIN_LIFESPAN` int(11) DEFAULT NULL,
  `INTERNATIONALIZATION_ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `DEFAULT_LOCALE` varchar(255) DEFAULT NULL,
  `REG_EMAIL_AS_USERNAME` bit(1) NOT NULL DEFAULT b'0',
  `ADMIN_EVENTS_ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `ADMIN_EVENTS_DETAILS_ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `EDIT_USERNAME_ALLOWED` bit(1) NOT NULL DEFAULT b'0',
  `OTP_POLICY_COUNTER` int(11) DEFAULT 0,
  `OTP_POLICY_WINDOW` int(11) DEFAULT 1,
  `OTP_POLICY_PERIOD` int(11) DEFAULT 30,
  `OTP_POLICY_DIGITS` int(11) DEFAULT 6,
  `OTP_POLICY_ALG` varchar(36) DEFAULT 'HmacSHA1',
  `OTP_POLICY_TYPE` varchar(36) DEFAULT 'totp',
  `BROWSER_FLOW` varchar(36) DEFAULT NULL,
  `REGISTRATION_FLOW` varchar(36) DEFAULT NULL,
  `DIRECT_GRANT_FLOW` varchar(36) DEFAULT NULL,
  `RESET_CREDENTIALS_FLOW` varchar(36) DEFAULT NULL,
  `CLIENT_AUTH_FLOW` varchar(36) DEFAULT NULL,
  `OFFLINE_SESSION_IDLE_TIMEOUT` int(11) DEFAULT 0,
  `REVOKE_REFRESH_TOKEN` bit(1) NOT NULL DEFAULT b'0',
  `ACCESS_TOKEN_LIFE_IMPLICIT` int(11) DEFAULT 0,
  `LOGIN_WITH_EMAIL_ALLOWED` bit(1) NOT NULL DEFAULT b'1',
  `DUPLICATE_EMAILS_ALLOWED` bit(1) NOT NULL DEFAULT b'0',
  `DOCKER_AUTH_FLOW` varchar(36) DEFAULT NULL,
  `REFRESH_TOKEN_MAX_REUSE` int(11) DEFAULT 0,
  `ALLOW_USER_MANAGED_ACCESS` bit(1) NOT NULL DEFAULT b'0',
  `SSO_MAX_LIFESPAN_REMEMBER_ME` int(11) NOT NULL,
  `SSO_IDLE_TIMEOUT_REMEMBER_ME` int(11) NOT NULL,
  `DEFAULT_ROLE` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UK_ORVSDMLA56612EAEFIQ6WL5OI` (`NAME`),
  KEY `IDX_REALM_MASTER_ADM_CLI` (`MASTER_ADMIN_CLIENT`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REALM`
--

LOCK TABLES `REALM` WRITE;
/*!40000 ALTER TABLE `REALM` DISABLE KEYS */;
INSERT INTO `REALM` VALUES
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',60,300,60,NULL,NULL,NULL,'','\0',0,NULL,'master',0,NULL,'\0','\0','\0','\0','EXTERNAL',1800,36000,'\0','\0','dae1aac5-fdd1-4ba9-8cfd-1ca8abc88a8b',1800,'\0',NULL,'\0','\0','\0','\0',0,1,30,6,'HmacSHA1','totp','2a0c99b8-9d40-44d4-8aa9-c051fc797660','f8db8a48-ae22-48de-920a-4d75fa7c93a4','12a7f999-a43e-473a-a05e-98f4d8587703','a1cbf9b5-224d-4e1e-a6bf-d780ec5a49a2','912298d3-c338-4ec1-8118-558c739617dd',2592000,'\0',900,'','\0','f40853ac-903a-4beb-99fa-9a8758b6f614',0,'\0',0,0,'c689852f-3f23-4e75-93cb-dc268de0198b'),
('dab18c5a-b240-4256-b8a9-31247dda96ac',60,300,300,'','','','','',31536000,'keycloak','contrabass',0,'length(8) and maxLength(12) and upperCase(1) and lowerCase(1) and specialChars(1) and digits(1)','','\0','','\0','EXTERNAL',1800,36000,'\0','\0','9db49952-1afc-4232-98ff-5adb2d5b8e72',1800,'','ko','','','','',0,1,30,6,'HmacSHA1','totp','4efe3e4a-9c6c-4be6-9dec-15455a18d4e9','7525e48e-e268-48bb-ae16-26e791a8774d','d2055d66-a9b7-4e74-9a10-e7ecfd9e8c1b','0d78c1a6-232b-44c0-ab89-02c34086e849','da0c5ab5-14a6-40b7-b100-de65281caa75',2592000,'\0',900,'','\0','fc0dd3c8-5b32-4d68-a1cb-cab3bc7930b1',0,'\0',0,0,'4cf898aa-f789-41da-898f-189dcb198e9a');
/*!40000 ALTER TABLE `REALM` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REALM_ATTRIBUTE`
--

DROP TABLE IF EXISTS `REALM_ATTRIBUTE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REALM_ATTRIBUTE` (
  `NAME` varchar(255) NOT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  `VALUE` longtext CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  PRIMARY KEY (`NAME`,`REALM_ID`),
  KEY `IDX_REALM_ATTR_REALM` (`REALM_ID`),
  CONSTRAINT `FK_8SHXD6L3E9ATQUKACXGPFFPTW` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REALM_ATTRIBUTE`
--

LOCK TABLES `REALM_ATTRIBUTE` WRITE;
/*!40000 ALTER TABLE `REALM_ATTRIBUTE` DISABLE KEYS */;
INSERT INTO `REALM_ATTRIBUTE` VALUES
('acr.loa.map','dab18c5a-b240-4256-b8a9-31247dda96ac','{}'),
('actionTokenGeneratedByAdminLifespan','dab18c5a-b240-4256-b8a9-31247dda96ac','43200'),
('actionTokenGeneratedByUserLifespan','dab18c5a-b240-4256-b8a9-31247dda96ac','300'),
('adminEventsExpiration','dab18c5a-b240-4256-b8a9-31247dda96ac','604800'),
('bruteForceProtected','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','false'),
('bruteForceProtected','dab18c5a-b240-4256-b8a9-31247dda96ac','false'),
('cibaAuthRequestedUserHint','dab18c5a-b240-4256-b8a9-31247dda96ac','login_hint'),
('cibaBackchannelTokenDeliveryMode','dab18c5a-b240-4256-b8a9-31247dda96ac','poll'),
('cibaExpiresIn','dab18c5a-b240-4256-b8a9-31247dda96ac','120'),
('cibaInterval','dab18c5a-b240-4256-b8a9-31247dda96ac','5'),
('client-policies.policies','dab18c5a-b240-4256-b8a9-31247dda96ac','{\"policies\":[]}'),
('client-policies.profiles','dab18c5a-b240-4256-b8a9-31247dda96ac','{\"profiles\":[]}'),
('clientOfflineSessionIdleTimeout','dab18c5a-b240-4256-b8a9-31247dda96ac','0'),
('clientOfflineSessionMaxLifespan','dab18c5a-b240-4256-b8a9-31247dda96ac','0'),
('clientSessionIdleTimeout','dab18c5a-b240-4256-b8a9-31247dda96ac','0'),
('clientSessionMaxLifespan','dab18c5a-b240-4256-b8a9-31247dda96ac','0'),
('defaultSignatureAlgorithm','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','RS256'),
('defaultSignatureAlgorithm','dab18c5a-b240-4256-b8a9-31247dda96ac','RS256'),
('displayName','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','Keycloak'),
('displayName','dab18c5a-b240-4256-b8a9-31247dda96ac',''),
('displayNameHtml','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','<div class=\"kc-logo-text\"><span>Keycloak</span></div>'),
('displayNameHtml','dab18c5a-b240-4256-b8a9-31247dda96ac','<span class=\'copy\'>(주)키클락</span>'),
('failureFactor','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','30'),
('failureFactor','dab18c5a-b240-4256-b8a9-31247dda96ac','30'),
('frontendUrl','dab18c5a-b240-4256-b8a9-31247dda96ac',''),
('maxDeltaTimeSeconds','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','43200'),
('maxDeltaTimeSeconds','dab18c5a-b240-4256-b8a9-31247dda96ac','43200'),
('maxFailureWaitSeconds','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','900'),
('maxFailureWaitSeconds','dab18c5a-b240-4256-b8a9-31247dda96ac','900'),
('minimumQuickLoginWaitSeconds','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','60'),
('minimumQuickLoginWaitSeconds','dab18c5a-b240-4256-b8a9-31247dda96ac','60'),
('oauth2DeviceCodeLifespan','dab18c5a-b240-4256-b8a9-31247dda96ac','600'),
('oauth2DevicePollingInterval','dab18c5a-b240-4256-b8a9-31247dda96ac','5'),
('offlineSessionMaxLifespan','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','5184000'),
('offlineSessionMaxLifespan','dab18c5a-b240-4256-b8a9-31247dda96ac','5184000'),
('offlineSessionMaxLifespanEnabled','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','false'),
('offlineSessionMaxLifespanEnabled','dab18c5a-b240-4256-b8a9-31247dda96ac','false'),
('parRequestUriLifespan','dab18c5a-b240-4256-b8a9-31247dda96ac','60'),
('permanentLockout','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','false'),
('permanentLockout','dab18c5a-b240-4256-b8a9-31247dda96ac','false'),
('quickLoginCheckMilliSeconds','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','1000'),
('quickLoginCheckMilliSeconds','dab18c5a-b240-4256-b8a9-31247dda96ac','1000'),
('realmReusableOtpCode','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','false'),
('realmReusableOtpCode','dab18c5a-b240-4256-b8a9-31247dda96ac','false'),
('waitIncrementSeconds','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','60'),
('waitIncrementSeconds','dab18c5a-b240-4256-b8a9-31247dda96ac','60'),
('webAuthnPolicyAttestationConveyancePreference','dab18c5a-b240-4256-b8a9-31247dda96ac','not specified'),
('webAuthnPolicyAttestationConveyancePreferencePasswordless','dab18c5a-b240-4256-b8a9-31247dda96ac','not specified'),
('webAuthnPolicyAuthenticatorAttachment','dab18c5a-b240-4256-b8a9-31247dda96ac','not specified'),
('webAuthnPolicyAuthenticatorAttachmentPasswordless','dab18c5a-b240-4256-b8a9-31247dda96ac','not specified'),
('webAuthnPolicyAvoidSameAuthenticatorRegister','dab18c5a-b240-4256-b8a9-31247dda96ac','false'),
('webAuthnPolicyAvoidSameAuthenticatorRegisterPasswordless','dab18c5a-b240-4256-b8a9-31247dda96ac','false'),
('webAuthnPolicyCreateTimeout','dab18c5a-b240-4256-b8a9-31247dda96ac','0'),
('webAuthnPolicyCreateTimeoutPasswordless','dab18c5a-b240-4256-b8a9-31247dda96ac','0'),
('webAuthnPolicyRequireResidentKey','dab18c5a-b240-4256-b8a9-31247dda96ac','not specified'),
('webAuthnPolicyRequireResidentKeyPasswordless','dab18c5a-b240-4256-b8a9-31247dda96ac','not specified'),
('webAuthnPolicyRpEntityName','dab18c5a-b240-4256-b8a9-31247dda96ac','keycloak'),
('webAuthnPolicyRpEntityNamePasswordless','dab18c5a-b240-4256-b8a9-31247dda96ac','keycloak'),
('webAuthnPolicyRpId','dab18c5a-b240-4256-b8a9-31247dda96ac',''),
('webAuthnPolicyRpIdPasswordless','dab18c5a-b240-4256-b8a9-31247dda96ac',''),
('webAuthnPolicySignatureAlgorithms','dab18c5a-b240-4256-b8a9-31247dda96ac','ES256'),
('webAuthnPolicySignatureAlgorithmsPasswordless','dab18c5a-b240-4256-b8a9-31247dda96ac','ES256'),
('webAuthnPolicyUserVerificationRequirement','dab18c5a-b240-4256-b8a9-31247dda96ac','not specified'),
('webAuthnPolicyUserVerificationRequirementPasswordless','dab18c5a-b240-4256-b8a9-31247dda96ac','not specified'),
('_browser_header.contentSecurityPolicy','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','frame-src \'self\'; frame-ancestors \'self\'; object-src \'none\';'),
('_browser_header.contentSecurityPolicy','dab18c5a-b240-4256-b8a9-31247dda96ac','frame-src \'self\'; frame-ancestors \'self\'; object-src \'none\';'),
('_browser_header.contentSecurityPolicyReportOnly','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86',''),
('_browser_header.contentSecurityPolicyReportOnly','dab18c5a-b240-4256-b8a9-31247dda96ac',''),
('_browser_header.referrerPolicy','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','no-referrer'),
('_browser_header.referrerPolicy','dab18c5a-b240-4256-b8a9-31247dda96ac','no-referrer'),
('_browser_header.strictTransportSecurity','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','max-age=31536000; includeSubDomains'),
('_browser_header.strictTransportSecurity','dab18c5a-b240-4256-b8a9-31247dda96ac','max-age=31536000; includeSubDomains; preload'),
('_browser_header.xContentTypeOptions','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','nosniff'),
('_browser_header.xContentTypeOptions','dab18c5a-b240-4256-b8a9-31247dda96ac','nosniff'),
('_browser_header.xFrameOptions','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','SAMEORIGIN'),
('_browser_header.xFrameOptions','dab18c5a-b240-4256-b8a9-31247dda96ac','SAMEORIGIN'),
('_browser_header.xRobotsTag','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','none'),
('_browser_header.xRobotsTag','dab18c5a-b240-4256-b8a9-31247dda96ac','none'),
('_browser_header.xXSSProtection','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','1; mode=block'),
('_browser_header.xXSSProtection','dab18c5a-b240-4256-b8a9-31247dda96ac','1; mode=block');
/*!40000 ALTER TABLE `REALM_ATTRIBUTE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REALM_DEFAULT_GROUPS`
--

DROP TABLE IF EXISTS `REALM_DEFAULT_GROUPS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REALM_DEFAULT_GROUPS` (
  `REALM_ID` varchar(36) NOT NULL,
  `GROUP_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`REALM_ID`,`GROUP_ID`),
  UNIQUE KEY `CON_GROUP_ID_DEF_GROUPS` (`GROUP_ID`),
  KEY `IDX_REALM_DEF_GRP_REALM` (`REALM_ID`),
  CONSTRAINT `FK_DEF_GROUPS_REALM` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REALM_DEFAULT_GROUPS`
--

LOCK TABLES `REALM_DEFAULT_GROUPS` WRITE;
/*!40000 ALTER TABLE `REALM_DEFAULT_GROUPS` DISABLE KEYS */;
/*!40000 ALTER TABLE `REALM_DEFAULT_GROUPS` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REALM_ENABLED_EVENT_TYPES`
--

DROP TABLE IF EXISTS `REALM_ENABLED_EVENT_TYPES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REALM_ENABLED_EVENT_TYPES` (
  `REALM_ID` varchar(36) NOT NULL,
  `VALUE` varchar(255) NOT NULL,
  PRIMARY KEY (`REALM_ID`,`VALUE`),
  KEY `IDX_REALM_EVT_TYPES_REALM` (`REALM_ID`),
  CONSTRAINT `FK_H846O4H0W8EPX5NWEDRF5Y69J` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REALM_ENABLED_EVENT_TYPES`
--

LOCK TABLES `REALM_ENABLED_EVENT_TYPES` WRITE;
/*!40000 ALTER TABLE `REALM_ENABLED_EVENT_TYPES` DISABLE KEYS */;
/*!40000 ALTER TABLE `REALM_ENABLED_EVENT_TYPES` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REALM_EVENTS_LISTENERS`
--

DROP TABLE IF EXISTS `REALM_EVENTS_LISTENERS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REALM_EVENTS_LISTENERS` (
  `REALM_ID` varchar(36) NOT NULL,
  `VALUE` varchar(255) NOT NULL,
  PRIMARY KEY (`REALM_ID`,`VALUE`),
  KEY `IDX_REALM_EVT_LIST_REALM` (`REALM_ID`),
  CONSTRAINT `FK_H846O4H0W8EPX5NXEV9F5Y69J` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REALM_EVENTS_LISTENERS`
--

LOCK TABLES `REALM_EVENTS_LISTENERS` WRITE;
/*!40000 ALTER TABLE `REALM_EVENTS_LISTENERS` DISABLE KEYS */;
INSERT INTO `REALM_EVENTS_LISTENERS` VALUES
('4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','jboss-logging'),
('dab18c5a-b240-4256-b8a9-31247dda96ac','jboss-logging');
/*!40000 ALTER TABLE `REALM_EVENTS_LISTENERS` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REALM_LOCALIZATIONS`
--

DROP TABLE IF EXISTS `REALM_LOCALIZATIONS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REALM_LOCALIZATIONS` (
  `REALM_ID` varchar(255) NOT NULL,
  `LOCALE` varchar(255) NOT NULL,
  `TEXTS` longtext CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  PRIMARY KEY (`REALM_ID`,`LOCALE`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REALM_LOCALIZATIONS`
--

LOCK TABLES `REALM_LOCALIZATIONS` WRITE;
/*!40000 ALTER TABLE `REALM_LOCALIZATIONS` DISABLE KEYS */;
/*!40000 ALTER TABLE `REALM_LOCALIZATIONS` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REALM_REQUIRED_CREDENTIAL`
--

DROP TABLE IF EXISTS `REALM_REQUIRED_CREDENTIAL`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REALM_REQUIRED_CREDENTIAL` (
  `TYPE` varchar(255) NOT NULL,
  `FORM_LABEL` varchar(255) DEFAULT NULL,
  `INPUT` bit(1) NOT NULL DEFAULT b'0',
  `SECRET` bit(1) NOT NULL DEFAULT b'0',
  `REALM_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`REALM_ID`,`TYPE`),
  CONSTRAINT `FK_5HG65LYBEVAVKQFKI3KPONH9V` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REALM_REQUIRED_CREDENTIAL`
--

LOCK TABLES `REALM_REQUIRED_CREDENTIAL` WRITE;
/*!40000 ALTER TABLE `REALM_REQUIRED_CREDENTIAL` DISABLE KEYS */;
INSERT INTO `REALM_REQUIRED_CREDENTIAL` VALUES
('password','password','','','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86'),
('password','password','','','dab18c5a-b240-4256-b8a9-31247dda96ac');
/*!40000 ALTER TABLE `REALM_REQUIRED_CREDENTIAL` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REALM_SMTP_CONFIG`
--

DROP TABLE IF EXISTS `REALM_SMTP_CONFIG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REALM_SMTP_CONFIG` (
  `REALM_ID` varchar(36) NOT NULL,
  `VALUE` varchar(255) DEFAULT NULL,
  `NAME` varchar(255) NOT NULL,
  PRIMARY KEY (`REALM_ID`,`NAME`),
  CONSTRAINT `FK_70EJ8XDXGXD0B9HH6180IRR0O` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REALM_SMTP_CONFIG`
--

LOCK TABLES `REALM_SMTP_CONFIG` WRITE;
/*!40000 ALTER TABLE `REALM_SMTP_CONFIG` DISABLE KEYS */;
/*!40000 ALTER TABLE `REALM_SMTP_CONFIG` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REALM_SUPPORTED_LOCALES`
--

DROP TABLE IF EXISTS `REALM_SUPPORTED_LOCALES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REALM_SUPPORTED_LOCALES` (
  `REALM_ID` varchar(36) NOT NULL,
  `VALUE` varchar(255) NOT NULL,
  PRIMARY KEY (`REALM_ID`,`VALUE`),
  KEY `IDX_REALM_SUPP_LOCAL_REALM` (`REALM_ID`),
  CONSTRAINT `FK_SUPPORTED_LOCALES_REALM` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REALM_SUPPORTED_LOCALES`
--

LOCK TABLES `REALM_SUPPORTED_LOCALES` WRITE;
/*!40000 ALTER TABLE `REALM_SUPPORTED_LOCALES` DISABLE KEYS */;
INSERT INTO `REALM_SUPPORTED_LOCALES` VALUES
('dab18c5a-b240-4256-b8a9-31247dda96ac','en'),
('dab18c5a-b240-4256-b8a9-31247dda96ac','ko');
/*!40000 ALTER TABLE `REALM_SUPPORTED_LOCALES` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REDIRECT_URIS`
--

DROP TABLE IF EXISTS `REDIRECT_URIS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REDIRECT_URIS` (
  `CLIENT_ID` varchar(36) NOT NULL,
  `VALUE` varchar(255) NOT NULL,
  PRIMARY KEY (`CLIENT_ID`,`VALUE`),
  KEY `IDX_REDIR_URI_CLIENT` (`CLIENT_ID`),
  CONSTRAINT `FK_1BURS8PB4OUJ97H5WUPPAHV9F` FOREIGN KEY (`CLIENT_ID`) REFERENCES `CLIENT` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REDIRECT_URIS`
--

LOCK TABLES `REDIRECT_URIS` WRITE;
/*!40000 ALTER TABLE `REDIRECT_URIS` DISABLE KEYS */;
INSERT INTO `REDIRECT_URIS` VALUES
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','/admin/contrabass/console/*'),
('21f67541-6b75-4f76-92e5-a2b7aa97937b','/realms/contrabass/account/*'),
('69b3d96b-db94-4825-b7be-95919a24d55a','/admin/master/console/*'),
('99663a99-9477-4699-a933-e91d41961578','/realms/contrabass/account/*'),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','/realms/master/account/*'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','https://contrabass.os:9443/oauth2/callback'),
('cf784c13-493e-4d43-86ee-8b9c81845b12','/realms/master/account/*');
/*!40000 ALTER TABLE `REDIRECT_URIS` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REQUIRED_ACTION_CONFIG`
--

DROP TABLE IF EXISTS `REQUIRED_ACTION_CONFIG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REQUIRED_ACTION_CONFIG` (
  `REQUIRED_ACTION_ID` varchar(36) NOT NULL,
  `VALUE` longtext DEFAULT NULL,
  `NAME` varchar(255) NOT NULL,
  PRIMARY KEY (`REQUIRED_ACTION_ID`,`NAME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REQUIRED_ACTION_CONFIG`
--

LOCK TABLES `REQUIRED_ACTION_CONFIG` WRITE;
/*!40000 ALTER TABLE `REQUIRED_ACTION_CONFIG` DISABLE KEYS */;
/*!40000 ALTER TABLE `REQUIRED_ACTION_CONFIG` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `REQUIRED_ACTION_PROVIDER`
--

DROP TABLE IF EXISTS `REQUIRED_ACTION_PROVIDER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `REQUIRED_ACTION_PROVIDER` (
  `ID` varchar(36) NOT NULL,
  `ALIAS` varchar(255) DEFAULT NULL,
  `NAME` varchar(255) DEFAULT NULL,
  `REALM_ID` varchar(36) DEFAULT NULL,
  `ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `DEFAULT_ACTION` bit(1) NOT NULL DEFAULT b'0',
  `PROVIDER_ID` varchar(255) DEFAULT NULL,
  `PRIORITY` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_REQ_ACT_PROV_REALM` (`REALM_ID`),
  CONSTRAINT `FK_REQ_ACT_REALM` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `REQUIRED_ACTION_PROVIDER`
--

LOCK TABLES `REQUIRED_ACTION_PROVIDER` WRITE;
/*!40000 ALTER TABLE `REQUIRED_ACTION_PROVIDER` DISABLE KEYS */;
INSERT INTO `REQUIRED_ACTION_PROVIDER` VALUES
('01463070-97a6-4b8c-9a9c-60802ee4c6c1','TERMS_AND_CONDITIONS','Terms and Conditions','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','\0','\0','TERMS_AND_CONDITIONS',20),
('0f27cdb3-c3d7-4015-90e2-b014d1b6918c','UPDATE_PASSWORD','Update Password','dab18c5a-b240-4256-b8a9-31247dda96ac','','\0','UPDATE_PASSWORD',30),
('1646211f-b7d7-47fb-8c2d-3bfe3ccc68da','TERMS_AND_CONDITIONS','Terms and Conditions','dab18c5a-b240-4256-b8a9-31247dda96ac','\0','\0','TERMS_AND_CONDITIONS',20),
('166abd23-22ae-421e-8a02-58acc83e5279','UPDATE_PROFILE','Update Profile','dab18c5a-b240-4256-b8a9-31247dda96ac','','\0','UPDATE_PROFILE',40),
('2b7342dc-cd08-4ebb-b975-535070cc4820','update_user_locale','Update User Locale','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','','\0','update_user_locale',1000),
('2ca90a3d-9aaa-4be1-a4b3-51583a253643','update_user_locale','Update User Locale','dab18c5a-b240-4256-b8a9-31247dda96ac','','\0','update_user_locale',1000),
('37c47770-93dd-41c8-bd95-082d3c5603ee','webauthn-register','Webauthn Register','dab18c5a-b240-4256-b8a9-31247dda96ac','','\0','webauthn-register',70),
('3db0ce0e-e5be-4fce-b937-16456c7a2b26','UPDATE_PASSWORD','Update Password','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','','\0','UPDATE_PASSWORD',30),
('713c452e-63cd-4a38-8221-a85b5bf9d3e3','webauthn-register-passwordless','Webauthn Register Passwordless','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','','\0','webauthn-register-passwordless',80),
('719bf20d-05b5-453e-8432-dc5eb5400aae','CONFIGURE_TOTP','Configure OTP','dab18c5a-b240-4256-b8a9-31247dda96ac','','\0','CONFIGURE_TOTP',10),
('7864c2e1-cb83-404d-a572-478d299712cb','delete_account','Delete Account','dab18c5a-b240-4256-b8a9-31247dda96ac','\0','\0','delete_account',60),
('7dde250c-f90b-48b1-9baf-c61e9c8618ca','CONFIGURE_TOTP','Configure OTP','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','','\0','CONFIGURE_TOTP',10),
('b138f75e-e770-47d4-b1f8-75120b33cf89','webauthn-register-passwordless','Webauthn Register Passwordless','dab18c5a-b240-4256-b8a9-31247dda96ac','','\0','webauthn-register-passwordless',80),
('b3772301-1192-49e8-856b-45f74c075a38','webauthn-register','Webauthn Register','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','','\0','webauthn-register',70),
('bf514132-deb2-4642-980a-41478491595a','delete_account','Delete Account','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','\0','\0','delete_account',60),
('dc47389c-ceb0-4ec3-9e3a-025e66be4192','VERIFY_EMAIL','Verify Email','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','','\0','VERIFY_EMAIL',50),
('dfd56a06-40cf-4880-a18a-d94ea430dc90','VERIFY_EMAIL','Verify Email','dab18c5a-b240-4256-b8a9-31247dda96ac','','\0','VERIFY_EMAIL',50),
('e2b0249f-2782-4471-bf52-73c077650a4a','UPDATE_PROFILE','Update Profile','4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','','\0','UPDATE_PROFILE',40);
/*!40000 ALTER TABLE `REQUIRED_ACTION_PROVIDER` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `RESOURCE_ATTRIBUTE`
--

DROP TABLE IF EXISTS `RESOURCE_ATTRIBUTE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `RESOURCE_ATTRIBUTE` (
  `ID` varchar(36) NOT NULL DEFAULT 'sybase-needs-something-here',
  `NAME` varchar(255) NOT NULL,
  `VALUE` varchar(255) DEFAULT NULL,
  `RESOURCE_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `FK_5HRM2VLF9QL5FU022KQEPOVBR` (`RESOURCE_ID`),
  CONSTRAINT `FK_5HRM2VLF9QL5FU022KQEPOVBR` FOREIGN KEY (`RESOURCE_ID`) REFERENCES `RESOURCE_SERVER_RESOURCE` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `RESOURCE_ATTRIBUTE`
--

LOCK TABLES `RESOURCE_ATTRIBUTE` WRITE;
/*!40000 ALTER TABLE `RESOURCE_ATTRIBUTE` DISABLE KEYS */;
/*!40000 ALTER TABLE `RESOURCE_ATTRIBUTE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `RESOURCE_POLICY`
--

DROP TABLE IF EXISTS `RESOURCE_POLICY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `RESOURCE_POLICY` (
  `RESOURCE_ID` varchar(36) NOT NULL,
  `POLICY_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`RESOURCE_ID`,`POLICY_ID`),
  KEY `IDX_RES_POLICY_POLICY` (`POLICY_ID`),
  CONSTRAINT `FK_FRSRPOS53XCX4WNKOG82SSRFY` FOREIGN KEY (`RESOURCE_ID`) REFERENCES `RESOURCE_SERVER_RESOURCE` (`ID`),
  CONSTRAINT `FK_FRSRPP213XCX4WNKOG82SSRFY` FOREIGN KEY (`POLICY_ID`) REFERENCES `RESOURCE_SERVER_POLICY` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `RESOURCE_POLICY`
--

LOCK TABLES `RESOURCE_POLICY` WRITE;
/*!40000 ALTER TABLE `RESOURCE_POLICY` DISABLE KEYS */;
/*!40000 ALTER TABLE `RESOURCE_POLICY` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `RESOURCE_SCOPE`
--

DROP TABLE IF EXISTS `RESOURCE_SCOPE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `RESOURCE_SCOPE` (
  `RESOURCE_ID` varchar(36) NOT NULL,
  `SCOPE_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`RESOURCE_ID`,`SCOPE_ID`),
  KEY `IDX_RES_SCOPE_SCOPE` (`SCOPE_ID`),
  CONSTRAINT `FK_FRSRPOS13XCX4WNKOG82SSRFY` FOREIGN KEY (`RESOURCE_ID`) REFERENCES `RESOURCE_SERVER_RESOURCE` (`ID`),
  CONSTRAINT `FK_FRSRPS213XCX4WNKOG82SSRFY` FOREIGN KEY (`SCOPE_ID`) REFERENCES `RESOURCE_SERVER_SCOPE` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `RESOURCE_SCOPE`
--

LOCK TABLES `RESOURCE_SCOPE` WRITE;
/*!40000 ALTER TABLE `RESOURCE_SCOPE` DISABLE KEYS */;
/*!40000 ALTER TABLE `RESOURCE_SCOPE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `RESOURCE_SERVER`
--

DROP TABLE IF EXISTS `RESOURCE_SERVER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `RESOURCE_SERVER` (
  `ID` varchar(36) NOT NULL,
  `ALLOW_RS_REMOTE_MGMT` bit(1) NOT NULL DEFAULT b'0',
  `POLICY_ENFORCE_MODE` tinyint(4) DEFAULT NULL,
  `DECISION_STRATEGY` tinyint(4) NOT NULL DEFAULT 1,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `RESOURCE_SERVER`
--

LOCK TABLES `RESOURCE_SERVER` WRITE;
/*!40000 ALTER TABLE `RESOURCE_SERVER` DISABLE KEYS */;
INSERT INTO `RESOURCE_SERVER` VALUES
('a866e702-403e-4aab-905d-18a4ef119cfe','\0',0,1),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','',0,1);
/*!40000 ALTER TABLE `RESOURCE_SERVER` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `RESOURCE_SERVER_PERM_TICKET`
--

DROP TABLE IF EXISTS `RESOURCE_SERVER_PERM_TICKET`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `RESOURCE_SERVER_PERM_TICKET` (
  `ID` varchar(36) NOT NULL,
  `OWNER` varchar(255) DEFAULT NULL,
  `REQUESTER` varchar(255) DEFAULT NULL,
  `CREATED_TIMESTAMP` bigint(20) NOT NULL,
  `GRANTED_TIMESTAMP` bigint(20) DEFAULT NULL,
  `RESOURCE_ID` varchar(36) NOT NULL,
  `SCOPE_ID` varchar(36) DEFAULT NULL,
  `RESOURCE_SERVER_ID` varchar(36) NOT NULL,
  `POLICY_ID` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UK_FRSR6T700S9V50BU18WS5PMT` (`OWNER`,`REQUESTER`,`RESOURCE_SERVER_ID`,`RESOURCE_ID`,`SCOPE_ID`),
  KEY `FK_FRSRHO213XCX4WNKOG82SSPMT` (`RESOURCE_SERVER_ID`),
  KEY `FK_FRSRHO213XCX4WNKOG83SSPMT` (`RESOURCE_ID`),
  KEY `FK_FRSRHO213XCX4WNKOG84SSPMT` (`SCOPE_ID`),
  KEY `FK_FRSRPO2128CX4WNKOG82SSRFY` (`POLICY_ID`),
  CONSTRAINT `FK_FRSRHO213XCX4WNKOG82SSPMT` FOREIGN KEY (`RESOURCE_SERVER_ID`) REFERENCES `RESOURCE_SERVER` (`ID`),
  CONSTRAINT `FK_FRSRHO213XCX4WNKOG83SSPMT` FOREIGN KEY (`RESOURCE_ID`) REFERENCES `RESOURCE_SERVER_RESOURCE` (`ID`),
  CONSTRAINT `FK_FRSRHO213XCX4WNKOG84SSPMT` FOREIGN KEY (`SCOPE_ID`) REFERENCES `RESOURCE_SERVER_SCOPE` (`ID`),
  CONSTRAINT `FK_FRSRPO2128CX4WNKOG82SSRFY` FOREIGN KEY (`POLICY_ID`) REFERENCES `RESOURCE_SERVER_POLICY` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `RESOURCE_SERVER_PERM_TICKET`
--

LOCK TABLES `RESOURCE_SERVER_PERM_TICKET` WRITE;
/*!40000 ALTER TABLE `RESOURCE_SERVER_PERM_TICKET` DISABLE KEYS */;
/*!40000 ALTER TABLE `RESOURCE_SERVER_PERM_TICKET` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `RESOURCE_SERVER_POLICY`
--

DROP TABLE IF EXISTS `RESOURCE_SERVER_POLICY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `RESOURCE_SERVER_POLICY` (
  `ID` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `DESCRIPTION` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `TYPE` varchar(255) NOT NULL,
  `DECISION_STRATEGY` tinyint(4) DEFAULT NULL,
  `LOGIC` tinyint(4) DEFAULT NULL,
  `RESOURCE_SERVER_ID` varchar(36) DEFAULT NULL,
  `OWNER` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UK_FRSRPT700S9V50BU18WS5HA6` (`NAME`,`RESOURCE_SERVER_ID`),
  KEY `IDX_RES_SERV_POL_RES_SERV` (`RESOURCE_SERVER_ID`),
  CONSTRAINT `FK_FRSRPO213XCX4WNKOG82SSRFY` FOREIGN KEY (`RESOURCE_SERVER_ID`) REFERENCES `RESOURCE_SERVER` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `RESOURCE_SERVER_POLICY`
--

LOCK TABLES `RESOURCE_SERVER_POLICY` WRITE;
/*!40000 ALTER TABLE `RESOURCE_SERVER_POLICY` DISABLE KEYS */;
/*!40000 ALTER TABLE `RESOURCE_SERVER_POLICY` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `RESOURCE_SERVER_RESOURCE`
--

DROP TABLE IF EXISTS `RESOURCE_SERVER_RESOURCE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `RESOURCE_SERVER_RESOURCE` (
  `ID` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `TYPE` varchar(255) DEFAULT NULL,
  `ICON_URI` varchar(255) DEFAULT NULL,
  `OWNER` varchar(255) DEFAULT NULL,
  `RESOURCE_SERVER_ID` varchar(36) DEFAULT NULL,
  `OWNER_MANAGED_ACCESS` bit(1) NOT NULL DEFAULT b'0',
  `DISPLAY_NAME` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UK_FRSR6T700S9V50BU18WS5HA6` (`NAME`,`OWNER`,`RESOURCE_SERVER_ID`),
  KEY `IDX_RES_SRV_RES_RES_SRV` (`RESOURCE_SERVER_ID`),
  CONSTRAINT `FK_FRSRHO213XCX4WNKOG82SSRFY` FOREIGN KEY (`RESOURCE_SERVER_ID`) REFERENCES `RESOURCE_SERVER` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `RESOURCE_SERVER_RESOURCE`
--

LOCK TABLES `RESOURCE_SERVER_RESOURCE` WRITE;
/*!40000 ALTER TABLE `RESOURCE_SERVER_RESOURCE` DISABLE KEYS */;
/*!40000 ALTER TABLE `RESOURCE_SERVER_RESOURCE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `RESOURCE_SERVER_SCOPE`
--

DROP TABLE IF EXISTS `RESOURCE_SERVER_SCOPE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `RESOURCE_SERVER_SCOPE` (
  `ID` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `ICON_URI` varchar(255) DEFAULT NULL,
  `RESOURCE_SERVER_ID` varchar(36) DEFAULT NULL,
  `DISPLAY_NAME` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UK_FRSRST700S9V50BU18WS5HA6` (`NAME`,`RESOURCE_SERVER_ID`),
  KEY `IDX_RES_SRV_SCOPE_RES_SRV` (`RESOURCE_SERVER_ID`),
  CONSTRAINT `FK_FRSRSO213XCX4WNKOG82SSRFY` FOREIGN KEY (`RESOURCE_SERVER_ID`) REFERENCES `RESOURCE_SERVER` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `RESOURCE_SERVER_SCOPE`
--

LOCK TABLES `RESOURCE_SERVER_SCOPE` WRITE;
/*!40000 ALTER TABLE `RESOURCE_SERVER_SCOPE` DISABLE KEYS */;
INSERT INTO `RESOURCE_SERVER_SCOPE` VALUES
('386e991d-385f-4c55-8474-39846c001f75','view',NULL,'a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('9157c540-334a-4987-8e83-a01194dc6fc1','manage-group-membership',NULL,'a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('9a33a2a3-5e5e-42cf-a1ed-30cd7656f3b9','manage',NULL,'a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('d702357e-daa7-46a2-b28a-7ee3123d17fb','user-impersonated',NULL,'a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('e9604044-6217-42c4-8b0b-0a502478c04b','map-roles',NULL,'a866e702-403e-4aab-905d-18a4ef119cfe',NULL),
('f176355d-a529-49de-9b45-007afb259bb5','impersonate',NULL,'a866e702-403e-4aab-905d-18a4ef119cfe',NULL);
/*!40000 ALTER TABLE `RESOURCE_SERVER_SCOPE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `RESOURCE_URIS`
--

DROP TABLE IF EXISTS `RESOURCE_URIS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `RESOURCE_URIS` (
  `RESOURCE_ID` varchar(36) NOT NULL,
  `VALUE` varchar(255) NOT NULL,
  PRIMARY KEY (`RESOURCE_ID`,`VALUE`),
  CONSTRAINT `FK_RESOURCE_SERVER_URIS` FOREIGN KEY (`RESOURCE_ID`) REFERENCES `RESOURCE_SERVER_RESOURCE` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `RESOURCE_URIS`
--

LOCK TABLES `RESOURCE_URIS` WRITE;
/*!40000 ALTER TABLE `RESOURCE_URIS` DISABLE KEYS */;
/*!40000 ALTER TABLE `RESOURCE_URIS` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ROLE_ATTRIBUTE`
--

DROP TABLE IF EXISTS `ROLE_ATTRIBUTE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ROLE_ATTRIBUTE` (
  `ID` varchar(36) NOT NULL,
  `ROLE_ID` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `VALUE` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_ROLE_ATTRIBUTE` (`ROLE_ID`),
  CONSTRAINT `FK_ROLE_ATTRIBUTE_ID` FOREIGN KEY (`ROLE_ID`) REFERENCES `KEYCLOAK_ROLE` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ROLE_ATTRIBUTE`
--

LOCK TABLES `ROLE_ATTRIBUTE` WRITE;
/*!40000 ALTER TABLE `ROLE_ATTRIBUTE` DISABLE KEYS */;
/*!40000 ALTER TABLE `ROLE_ATTRIBUTE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `SCOPE_MAPPING`
--

DROP TABLE IF EXISTS `SCOPE_MAPPING`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SCOPE_MAPPING` (
  `CLIENT_ID` varchar(36) NOT NULL,
  `ROLE_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`CLIENT_ID`,`ROLE_ID`),
  KEY `IDX_SCOPE_MAPPING_ROLE` (`ROLE_ID`),
  CONSTRAINT `FK_OUSE064PLMLR732LXJCN1Q5F1` FOREIGN KEY (`CLIENT_ID`) REFERENCES `CLIENT` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `SCOPE_MAPPING`
--

LOCK TABLES `SCOPE_MAPPING` WRITE;
/*!40000 ALTER TABLE `SCOPE_MAPPING` DISABLE KEYS */;
INSERT INTO `SCOPE_MAPPING` VALUES
('99663a99-9477-4699-a933-e91d41961578','2c773491-74b6-4d52-a196-14581d950b57'),
('99663a99-9477-4699-a933-e91d41961578','7207c52d-ebc5-4c1b-8cf9-cdbc8d42e65c'),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','04b9f1fa-05af-4d6e-84b2-5547bb07db93'),
('b2438863-f1f8-49f9-bc6b-e696f83a1aab','8235b970-ea81-4074-87e5-7a11d2cbbc1e');
/*!40000 ALTER TABLE `SCOPE_MAPPING` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `SCOPE_POLICY`
--

DROP TABLE IF EXISTS `SCOPE_POLICY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SCOPE_POLICY` (
  `SCOPE_ID` varchar(36) NOT NULL,
  `POLICY_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`SCOPE_ID`,`POLICY_ID`),
  KEY `IDX_SCOPE_POLICY_POLICY` (`POLICY_ID`),
  CONSTRAINT `FK_FRSRASP13XCX4WNKOG82SSRFY` FOREIGN KEY (`POLICY_ID`) REFERENCES `RESOURCE_SERVER_POLICY` (`ID`),
  CONSTRAINT `FK_FRSRPASS3XCX4WNKOG82SSRFY` FOREIGN KEY (`SCOPE_ID`) REFERENCES `RESOURCE_SERVER_SCOPE` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `SCOPE_POLICY`
--

LOCK TABLES `SCOPE_POLICY` WRITE;
/*!40000 ALTER TABLE `SCOPE_POLICY` DISABLE KEYS */;
/*!40000 ALTER TABLE `SCOPE_POLICY` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USERNAME_LOGIN_FAILURE`
--

DROP TABLE IF EXISTS `USERNAME_LOGIN_FAILURE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USERNAME_LOGIN_FAILURE` (
  `REALM_ID` varchar(36) NOT NULL,
  `USERNAME` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `FAILED_LOGIN_NOT_BEFORE` int(11) DEFAULT NULL,
  `LAST_FAILURE` bigint(20) DEFAULT NULL,
  `LAST_IP_FAILURE` varchar(255) DEFAULT NULL,
  `NUM_FAILURES` int(11) DEFAULT NULL,
  PRIMARY KEY (`REALM_ID`,`USERNAME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USERNAME_LOGIN_FAILURE`
--

LOCK TABLES `USERNAME_LOGIN_FAILURE` WRITE;
/*!40000 ALTER TABLE `USERNAME_LOGIN_FAILURE` DISABLE KEYS */;
/*!40000 ALTER TABLE `USERNAME_LOGIN_FAILURE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_ATTRIBUTE`
--

DROP TABLE IF EXISTS `USER_ATTRIBUTE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_ATTRIBUTE` (
  `NAME` varchar(255) NOT NULL,
  `VALUE` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `USER_ID` varchar(36) NOT NULL,
  `ID` varchar(36) NOT NULL DEFAULT 'sybase-needs-something-here',
  PRIMARY KEY (`ID`),
  KEY `IDX_USER_ATTRIBUTE` (`USER_ID`),
  KEY `IDX_USER_ATTRIBUTE_NAME` (`NAME`,`VALUE`),
  CONSTRAINT `FK_5HRM2VLF9QL5FU043KQEPOVBR` FOREIGN KEY (`USER_ID`) REFERENCES `USER_ENTITY` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_ATTRIBUTE`
--

LOCK TABLES `USER_ATTRIBUTE` WRITE;
/*!40000 ALTER TABLE `USER_ATTRIBUTE` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_ATTRIBUTE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_CONSENT`
--

DROP TABLE IF EXISTS `USER_CONSENT`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_CONSENT` (
  `ID` varchar(36) NOT NULL,
  `CLIENT_ID` varchar(255) DEFAULT NULL,
  `USER_ID` varchar(36) NOT NULL,
  `CREATED_DATE` bigint(20) DEFAULT NULL,
  `LAST_UPDATED_DATE` bigint(20) DEFAULT NULL,
  `CLIENT_STORAGE_PROVIDER` varchar(36) DEFAULT NULL,
  `EXTERNAL_CLIENT_ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UK_JKUWUVD56ONTGSUHOGM8UEWRT` (`CLIENT_ID`,`CLIENT_STORAGE_PROVIDER`,`EXTERNAL_CLIENT_ID`,`USER_ID`),
  KEY `IDX_USER_CONSENT` (`USER_ID`),
  CONSTRAINT `FK_GRNTCSNT_USER` FOREIGN KEY (`USER_ID`) REFERENCES `USER_ENTITY` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_CONSENT`
--

LOCK TABLES `USER_CONSENT` WRITE;
/*!40000 ALTER TABLE `USER_CONSENT` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_CONSENT` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_CONSENT_CLIENT_SCOPE`
--

DROP TABLE IF EXISTS `USER_CONSENT_CLIENT_SCOPE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_CONSENT_CLIENT_SCOPE` (
  `USER_CONSENT_ID` varchar(36) NOT NULL,
  `SCOPE_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`USER_CONSENT_ID`,`SCOPE_ID`),
  KEY `IDX_USCONSENT_CLSCOPE` (`USER_CONSENT_ID`),
  CONSTRAINT `FK_GRNTCSNT_CLSC_USC` FOREIGN KEY (`USER_CONSENT_ID`) REFERENCES `USER_CONSENT` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_CONSENT_CLIENT_SCOPE`
--

LOCK TABLES `USER_CONSENT_CLIENT_SCOPE` WRITE;
/*!40000 ALTER TABLE `USER_CONSENT_CLIENT_SCOPE` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_CONSENT_CLIENT_SCOPE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_ENTITY`
--

DROP TABLE IF EXISTS `USER_ENTITY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_ENTITY` (
  `ID` varchar(36) NOT NULL,
  `EMAIL` varchar(255) DEFAULT NULL,
  `EMAIL_CONSTRAINT` varchar(255) DEFAULT NULL,
  `EMAIL_VERIFIED` bit(1) NOT NULL DEFAULT b'0',
  `ENABLED` bit(1) NOT NULL DEFAULT b'0',
  `FEDERATION_LINK` varchar(255) DEFAULT NULL,
  `FIRST_NAME` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `LAST_NAME` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `REALM_ID` varchar(255) DEFAULT NULL,
  `USERNAME` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `CREATED_TIMESTAMP` bigint(20) DEFAULT NULL,
  `SERVICE_ACCOUNT_CLIENT_LINK` varchar(255) DEFAULT NULL,
  `NOT_BEFORE` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `UK_DYKN684SL8UP1CRFEI6ECKHD7` (`REALM_ID`,`EMAIL_CONSTRAINT`),
  UNIQUE KEY `UK_RU8TT6T700S9V50BU18WS5HA6` (`REALM_ID`,`USERNAME`),
  KEY `IDX_USER_EMAIL` (`EMAIL`),
  KEY `IDX_USER_SERVICE_ACCOUNT` (`REALM_ID`,`SERVICE_ACCOUNT_CLIENT_LINK`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_ENTITY`
--

LOCK TABLES `USER_ENTITY` WRITE;
/*!40000 ALTER TABLE `USER_ENTITY` DISABLE KEYS */;
INSERT INTO `USER_ENTITY` VALUES
('172884f4-1ce9-45c2-b681-de1af69ff5d8',NULL,'59fe36c3-2e8c-4de4-9de7-30a50da5be0a','\0','',NULL,NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','service-account-contrabass-client',1696385086907,'c4e639d7-8646-4f98-a9ba-c66d912ea13b',0),
('650758f6-3448-4985-a3d6-d925830b1cb5','maestro@okestro.com','maestro@okestro.com','\0','',NULL,NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','maestro@okestro.com',NULL,NULL,0),
('6a0aaa6e-460a-488c-ae61-f5703d03fa3b',NULL,'ebc63fe4-b4d3-4d50-a893-c494e1911d7b','\0','',NULL,NULL,NULL,'4a7c9b0e-ba20-44c9-8c04-3e8f38f19c86','admin',1743396845561,NULL,0),
('8845528e-64d2-4c50-a1c8-253893464aac',NULL,'c34750c2-0988-4d10-af5b-9fd28f8dd31c','\0','',NULL,NULL,NULL,'dab18c5a-b240-4256-b8a9-31247dda96ac','service-account-realm-management',1706539174767,'a866e702-403e-4aab-905d-18a4ef119cfe',0);
/*!40000 ALTER TABLE `USER_ENTITY` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_FEDERATION_CONFIG`
--

DROP TABLE IF EXISTS `USER_FEDERATION_CONFIG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_FEDERATION_CONFIG` (
  `USER_FEDERATION_PROVIDER_ID` varchar(36) NOT NULL,
  `VALUE` varchar(255) DEFAULT NULL,
  `NAME` varchar(255) NOT NULL,
  PRIMARY KEY (`USER_FEDERATION_PROVIDER_ID`,`NAME`),
  CONSTRAINT `FK_T13HPU1J94R2EBPEKR39X5EU5` FOREIGN KEY (`USER_FEDERATION_PROVIDER_ID`) REFERENCES `USER_FEDERATION_PROVIDER` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_FEDERATION_CONFIG`
--

LOCK TABLES `USER_FEDERATION_CONFIG` WRITE;
/*!40000 ALTER TABLE `USER_FEDERATION_CONFIG` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_FEDERATION_CONFIG` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_FEDERATION_MAPPER`
--

DROP TABLE IF EXISTS `USER_FEDERATION_MAPPER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_FEDERATION_MAPPER` (
  `ID` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `FEDERATION_PROVIDER_ID` varchar(36) NOT NULL,
  `FEDERATION_MAPPER_TYPE` varchar(255) NOT NULL,
  `REALM_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_USR_FED_MAP_FED_PRV` (`FEDERATION_PROVIDER_ID`),
  KEY `IDX_USR_FED_MAP_REALM` (`REALM_ID`),
  CONSTRAINT `FK_FEDMAPPERPM_FEDPRV` FOREIGN KEY (`FEDERATION_PROVIDER_ID`) REFERENCES `USER_FEDERATION_PROVIDER` (`ID`),
  CONSTRAINT `FK_FEDMAPPERPM_REALM` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_FEDERATION_MAPPER`
--

LOCK TABLES `USER_FEDERATION_MAPPER` WRITE;
/*!40000 ALTER TABLE `USER_FEDERATION_MAPPER` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_FEDERATION_MAPPER` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_FEDERATION_MAPPER_CONFIG`
--

DROP TABLE IF EXISTS `USER_FEDERATION_MAPPER_CONFIG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_FEDERATION_MAPPER_CONFIG` (
  `USER_FEDERATION_MAPPER_ID` varchar(36) NOT NULL,
  `VALUE` varchar(255) DEFAULT NULL,
  `NAME` varchar(255) NOT NULL,
  PRIMARY KEY (`USER_FEDERATION_MAPPER_ID`,`NAME`),
  CONSTRAINT `FK_FEDMAPPER_CFG` FOREIGN KEY (`USER_FEDERATION_MAPPER_ID`) REFERENCES `USER_FEDERATION_MAPPER` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_FEDERATION_MAPPER_CONFIG`
--

LOCK TABLES `USER_FEDERATION_MAPPER_CONFIG` WRITE;
/*!40000 ALTER TABLE `USER_FEDERATION_MAPPER_CONFIG` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_FEDERATION_MAPPER_CONFIG` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_FEDERATION_PROVIDER`
--

DROP TABLE IF EXISTS `USER_FEDERATION_PROVIDER`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_FEDERATION_PROVIDER` (
  `ID` varchar(36) NOT NULL,
  `CHANGED_SYNC_PERIOD` int(11) DEFAULT NULL,
  `DISPLAY_NAME` varchar(255) DEFAULT NULL,
  `FULL_SYNC_PERIOD` int(11) DEFAULT NULL,
  `LAST_SYNC` int(11) DEFAULT NULL,
  `PRIORITY` int(11) DEFAULT NULL,
  `PROVIDER_NAME` varchar(255) DEFAULT NULL,
  `REALM_ID` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IDX_USR_FED_PRV_REALM` (`REALM_ID`),
  CONSTRAINT `FK_1FJ32F6PTOLW2QY60CD8N01E8` FOREIGN KEY (`REALM_ID`) REFERENCES `REALM` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_FEDERATION_PROVIDER`
--

LOCK TABLES `USER_FEDERATION_PROVIDER` WRITE;
/*!40000 ALTER TABLE `USER_FEDERATION_PROVIDER` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_FEDERATION_PROVIDER` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_GROUP_MEMBERSHIP`
--

DROP TABLE IF EXISTS `USER_GROUP_MEMBERSHIP`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_GROUP_MEMBERSHIP` (
  `GROUP_ID` varchar(36) NOT NULL,
  `USER_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`GROUP_ID`,`USER_ID`),
  KEY `IDX_USER_GROUP_MAPPING` (`USER_ID`),
  CONSTRAINT `FK_USER_GROUP_USER` FOREIGN KEY (`USER_ID`) REFERENCES `USER_ENTITY` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_GROUP_MEMBERSHIP`
--

LOCK TABLES `USER_GROUP_MEMBERSHIP` WRITE;
/*!40000 ALTER TABLE `USER_GROUP_MEMBERSHIP` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_GROUP_MEMBERSHIP` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_IDENTITY_VERIFICATION`
--

DROP TABLE IF EXISTS `USER_IDENTITY_VERIFICATION`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_IDENTITY_VERIFICATION` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `credential_code` varchar(255) DEFAULT NULL,
  `expire_date` timestamp NOT NULL DEFAULT current_timestamp(),
  `repeat_count` int(11) DEFAULT 0,
  `auth_type` varchar(255) DEFAULT NULL,
  `channel_type` varchar(255) DEFAULT NULL,
  `channel_type_value` varchar(255) DEFAULT NULL,
  `updated_timestamp` timestamp NULL DEFAULT NULL,
  `created_timestamp` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_IDENTITY_VERIFICATION`
--

LOCK TABLES `USER_IDENTITY_VERIFICATION` WRITE;
/*!40000 ALTER TABLE `USER_IDENTITY_VERIFICATION` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_IDENTITY_VERIFICATION` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_MFA`
--

DROP TABLE IF EXISTS `USER_MFA`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_MFA` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `user_id` varchar(255) DEFAULT NULL,
  `credential_code` varchar(255) DEFAULT NULL,
  `expire_date` timestamp NOT NULL DEFAULT current_timestamp(),
  `repeat_count` int(11) DEFAULT 0,
  `created_timestamp` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_MFA`
--

LOCK TABLES `USER_MFA` WRITE;
/*!40000 ALTER TABLE `USER_MFA` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_MFA` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_REQUIRED_ACTION`
--

DROP TABLE IF EXISTS `USER_REQUIRED_ACTION`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_REQUIRED_ACTION` (
  `USER_ID` varchar(36) NOT NULL,
  `REQUIRED_ACTION` varchar(255) NOT NULL DEFAULT ' ',
  PRIMARY KEY (`REQUIRED_ACTION`,`USER_ID`),
  KEY `IDX_USER_REQACTIONS` (`USER_ID`),
  CONSTRAINT `FK_6QJ3W1JW9CVAFHE19BWSIUVMD` FOREIGN KEY (`USER_ID`) REFERENCES `USER_ENTITY` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_REQUIRED_ACTION`
--

LOCK TABLES `USER_REQUIRED_ACTION` WRITE;
/*!40000 ALTER TABLE `USER_REQUIRED_ACTION` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_REQUIRED_ACTION` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_ROLE_MAPPING`
--

DROP TABLE IF EXISTS `USER_ROLE_MAPPING`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_ROLE_MAPPING` (
  `ROLE_ID` varchar(255) NOT NULL,
  `USER_ID` varchar(36) NOT NULL,
  PRIMARY KEY (`ROLE_ID`,`USER_ID`),
  KEY `IDX_USER_ROLE_MAPPING` (`USER_ID`),
  CONSTRAINT `FK_C4FQV34P1MBYLLOXANG7B1Q3L` FOREIGN KEY (`USER_ID`) REFERENCES `USER_ENTITY` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_ROLE_MAPPING`
--

LOCK TABLES `USER_ROLE_MAPPING` WRITE;
/*!40000 ALTER TABLE `USER_ROLE_MAPPING` DISABLE KEYS */;
INSERT INTO `USER_ROLE_MAPPING` VALUES
('1ab2166c-4977-4d5d-bda2-ff551379b87c','172884f4-1ce9-45c2-b681-de1af69ff5d8'),
('3b072ba0-29ed-4177-91be-1c9423b1bdd6','650758f6-3448-4985-a3d6-d925830b1cb5'),
('4cf898aa-f789-41da-898f-189dcb198e9a','172884f4-1ce9-45c2-b681-de1af69ff5d8'),
('4cf898aa-f789-41da-898f-189dcb198e9a','8845528e-64d2-4c50-a1c8-253893464aac'),
('7207c52d-ebc5-4c1b-8cf9-cdbc8d42e65c','650758f6-3448-4985-a3d6-d925830b1cb5'),
('7a606b7f-2ff5-4c0a-82f0-c88f98d349bb','8845528e-64d2-4c50-a1c8-253893464aac'),
('a1e46ff6-a773-426f-b39b-be0f6eb93d3f','6a0aaa6e-460a-488c-ae61-f5703d03fa3b'),
('bc708560-c9e3-4b04-b300-a33f20cb41e5','650758f6-3448-4985-a3d6-d925830b1cb5'),
('c689852f-3f23-4e75-93cb-dc268de0198b','6a0aaa6e-460a-488c-ae61-f5703d03fa3b'),
('f4b3e6be-a3dd-42af-a25c-fdfabce36bc6','650758f6-3448-4985-a3d6-d925830b1cb5');
/*!40000 ALTER TABLE `USER_ROLE_MAPPING` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_SESSION`
--

DROP TABLE IF EXISTS `USER_SESSION`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_SESSION` (
  `ID` varchar(36) NOT NULL,
  `AUTH_METHOD` varchar(255) DEFAULT NULL,
  `IP_ADDRESS` varchar(255) DEFAULT NULL,
  `LAST_SESSION_REFRESH` int(11) DEFAULT NULL,
  `LOGIN_USERNAME` varchar(255) DEFAULT NULL,
  `REALM_ID` varchar(255) DEFAULT NULL,
  `REMEMBER_ME` bit(1) NOT NULL DEFAULT b'0',
  `STARTED` int(11) DEFAULT NULL,
  `USER_ID` varchar(255) DEFAULT NULL,
  `USER_SESSION_STATE` int(11) DEFAULT NULL,
  `BROKER_SESSION_ID` varchar(255) DEFAULT NULL,
  `BROKER_USER_ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_SESSION`
--

LOCK TABLES `USER_SESSION` WRITE;
/*!40000 ALTER TABLE `USER_SESSION` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_SESSION` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_SESSION_NOTE`
--

DROP TABLE IF EXISTS `USER_SESSION_NOTE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_SESSION_NOTE` (
  `USER_SESSION` varchar(36) NOT NULL,
  `NAME` varchar(255) NOT NULL,
  `VALUE` text DEFAULT NULL,
  PRIMARY KEY (`USER_SESSION`,`NAME`),
  CONSTRAINT `FK5EDFB00FF51D3472` FOREIGN KEY (`USER_SESSION`) REFERENCES `USER_SESSION` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_SESSION_NOTE`
--

LOCK TABLES `USER_SESSION_NOTE` WRITE;
/*!40000 ALTER TABLE `USER_SESSION_NOTE` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_SESSION_NOTE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `USER_TEMPORARY_AUTH_COOKIE`
--

DROP TABLE IF EXISTS `USER_TEMPORARY_AUTH_COOKIE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `USER_TEMPORARY_AUTH_COOKIE` (
  `id` varchar(255) NOT NULL DEFAULT uuid(),
  `value` varchar(255) DEFAULT NULL,
  `expire_date` timestamp NOT NULL DEFAULT current_timestamp(),
  `auth_type` varchar(255) DEFAULT NULL,
  `created_timestamp` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `USER_TEMPORARY_AUTH_COOKIE`
--

LOCK TABLES `USER_TEMPORARY_AUTH_COOKIE` WRITE;
/*!40000 ALTER TABLE `USER_TEMPORARY_AUTH_COOKIE` DISABLE KEYS */;
/*!40000 ALTER TABLE `USER_TEMPORARY_AUTH_COOKIE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `WEB_ORIGINS`
--

DROP TABLE IF EXISTS `WEB_ORIGINS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WEB_ORIGINS` (
  `CLIENT_ID` varchar(36) NOT NULL,
  `VALUE` varchar(255) NOT NULL,
  PRIMARY KEY (`CLIENT_ID`,`VALUE`),
  KEY `IDX_WEB_ORIG_CLIENT` (`CLIENT_ID`),
  CONSTRAINT `FK_LOJPHO213XCX4WNKOG82SSRFY` FOREIGN KEY (`CLIENT_ID`) REFERENCES `CLIENT` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `WEB_ORIGINS`
--

LOCK TABLES `WEB_ORIGINS` WRITE;
/*!40000 ALTER TABLE `WEB_ORIGINS` DISABLE KEYS */;
INSERT INTO `WEB_ORIGINS` VALUES
('0e283c44-f7e1-407a-b5ad-7593a14aa8db','+'),
('69b3d96b-db94-4825-b7be-95919a24d55a','+'),
('c4e639d7-8646-4f98-a9ba-c66d912ea13b','*');
/*!40000 ALTER TABLE `WEB_ORIGINS` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-04-02  3:41:32
