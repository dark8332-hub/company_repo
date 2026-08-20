USE dp_common;

INSERT INTO dp_common.cb_app_type
(id, app_name)
VALUES(1, 'CONTRABASS');


INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(1, 'compute__do_build_and_run_instance', 'nova', '인스턴스 생성', 1, '인스턴스 생성 이벤트', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(2, 'compute_start_instance', 'nova', '인스턴스 시작', 1, '인스턴스 시작 이벤트', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(3, 'compute_stop_instance', 'nova', '인스턴스 종료', 1, '인스턴스 종료 이벤트', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(4, 'compute_terminate_instance', 'nova', '인스턴스 삭제', 1, '인스턴스 삭제 이벤트', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(5, 'compute_prep_resize', 'nova', '유형변경 준비', 0, '인스턴스 유형 변경 준비', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(6, 'compute_resize_instance', 'nova', '유형변경 진행', 0, '인스턴스 유형 변경 중', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(7, 'compute_finish_resize', 'nova', '유형변경', 0, '인스턴스 유형 변경 완료', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(8, 'compute_confirm_resize', 'nova', '유형변경', 1, '인스턴스 유형 변경 확인', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(9, 'compute_check_can_live_migrate_destination', 'nova', '라이브 마이그레이션', 0, 'LIVE MIGRATION 진행 가능 여부 확인(목적지)', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(10, 'compute_check_can_live_migrate_source', 'nova', '라이브 마이그레이션', 0, 'LIVE MIGRATION 진행 가능 여부 확인(소스)', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(11, 'compute_live_migration', 'nova', '라이브 마이그레이션', 0, 'LIVE MIGRATION 수행', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(12, 'compute_pre_live_migration', 'nova', '라이브 마이그레이션', 0, 'LIVE MIGRATION 사전 작업', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(13, 'compute_post_live_migration_at_destination', 'nova', '라이브 마이그레이션', 1, 'LIVE MIGRATION 완료 후 목적지 설정', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(14, 'compute_rollback_live_migration_at_destination', 'nova', '라이브 마이그레이션', 1, 'LIVE MIGRATION 롤백 진행', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(15, 'compute_reboot_instance', 'nova', '인스턴스 재부팅', 1, '인스턴스 (하드, 소프트)재부팅 이벤트', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(16, 'compute_attach_volume', 'nova', '볼륨 추가', 1, '볼륨 추가 이벤트', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(17, 'compute_detach_volume', 'nova', '볼륨 제거', 1, '볼륨 제거 이벤트', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(18, 'compute_snapshot_instance', 'nova', '스냅샷 생성', 0, '인스턴스 스냅샷 생성', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(19, 'compute_attach_interface', 'nova', '인터페이스 연결', 1, '인터페이스 연결 이벤트', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(20, 'compute_detach_interface', 'nova', '인터페이스 연결 해제', 1, '인터페이스 연결 해제 이벤트', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(21, 'image_snapshot_pending', 'nova', '이미지 스냅샷 대기', 0, '이미지 스냅샷이 대기 중', '2025-01-14 04:37:38.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(22, 'volume.create.start', 'cinder', '볼륨 생성', 0, '볼륨 생성이 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(23, 'volume.create.end', 'cinder', '볼륨 생성', 1, '볼륨 생성이 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(24, 'volume.update.start', 'cinder', '볼륨 수정', 0, '볼륨 수정이 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(25, 'volume.update.end', 'cinder', '볼륨 수정', 1, '볼륨 수정이 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(26, 'volume.delete.start', 'cinder', '볼륨 삭제', 0, '볼륨 삭제가 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(27, 'volume.delete.end', 'cinder', '볼륨 삭제', 1, '볼륨 삭제가 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(28, 'volume.reset_status.start', 'cinder', '볼륨 상태 변경', 0, '볼륨 상태 변경이 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(29, 'volume.reset_status.end', 'cinder', '볼륨 상태 변경', 1, '볼륨 상태 변경이 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(30, 'backup.create.start', 'cinder', '볼륨 백업', 0, '볼륨 백업이 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(31, 'backup.create.end', 'cinder', '볼륨 백업', 1, '볼륨 백업이 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(32, 'backup.delete.start', 'cinder', '볼륨 백업 삭제', 0, '볼륨 백업 삭제가 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(33, 'backup.delete.end', 'cinder', '볼륨 백업 삭제', 1, '볼륨 백업 삭제가 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(34, 'volume.resize.start', 'cinder', '볼륨 확장', 0, '볼륨 확장이 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(35, 'volume.resize.end', 'cinder', '볼륨 확장', 1, '볼륨 확장이 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(36, 'volume.retype', 'cinder', '스토리지 마이그레이션', 1, '스토리지 마이그레이션이 진행됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(37, 'volume.attach.start', 'cinder', '볼륨 연결', 0, '볼륨 연결이 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(38, 'volume.attach.end', 'cinder', '볼륨 연결', 1, '볼륨 연결이 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(39, 'volume.detach.start', 'cinder', '볼륨 연결 해제', 0, '볼륨 연결 해제가 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(40, 'volume.detach.end', 'cinder', '볼륨 연결 해제', 1, '볼륨 연결 해제가 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(41, 'snapshot.create.start', 'cinder', '스냅샷 생성', 0, '스냅샷 생성이 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(42, 'snapshot.create.end', 'cinder', '스냅샷 생성', 1, '스냅샷 생성이 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(43, 'snapshot.update.start', 'cinder', '스냅샷 수정', 0, '스냅샷 수정이 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(44, 'snapshot.update.end', 'cinder', '스냅샷 수정', 1, '스냅샷 수정이 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(45, 'snapshot.reset_status.start', 'cinder', '스냅샷 상태 변경', 0, '스냅샷 상태 변경이 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(46, 'snapshot.reset_status.end', 'cinder', '스냅샷 상태 변경', 1, '스냅샷 상태 변경이 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(47, 'snapshot.delete.start', 'cinder', '스냅샷 삭제', 0, '스냅샷 삭제가 시작됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(48, 'snapshot.delete.end', 'cinder', '스냅샷 삭제', 1, '스냅샷 삭제가 완료됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(49, 'volume_type.create', 'cinder', '볼륨 타입', 0, '볼륨 타입이 생성됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(50, 'volume_type.delete', 'cinder', '볼륨 타입', 0, '볼륨 타입이 삭제됨', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(51, 'backup.createprogress', 'cinder', '볼륨 백업 에러', 0, '볼륨 백업 생성 중 에러 발생', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(52, 'scheduler.create_volume', 'cinder', '볼륨 생성 에러', 1, '볼륨 생성 중 스케줄러 에러 발생', '2025-01-14 05:08:11.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(53, 'identity.project.created', 'keystone', '프로젝트 생성', 1, '프로젝트 생성이 완료됨', '2025-01-14 05:12:07.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(54, 'identity.project.updated', 'keystone', '프로젝트 수정', 1, '프로젝트 수정이 완료됨', '2025-01-14 05:12:07.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(55, 'identity.project.deleted', 'keystone', '프로젝트 삭제', 1, '프로젝트 삭제가 완료됨', '2025-01-14 05:12:07.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(56, 'image.create', 'glance', '이미지 생성', 0, '이미지 생성 이벤트', '2025-01-14 06:55:25.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(57, 'image.member.create', 'glance', '이미지 멤버 생성', 0, '이미지 멤버 생성 이벤트', '2025-01-14 06:55:25.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(60, 'image.prepare', 'glance', '이미지 저장 준비', 0, '이미지 저장 준비 중', '2025-01-14 06:55:25.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(61, 'image.upload', 'glance', '이미지 업로드', 0, '이미지 업로드 활성화', '2025-01-14 06:55:25.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(62, 'image.activate', 'glance', '이미지 활성화', 0, '이미지 활성화 진행 중', '2025-01-14 06:55:25.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(63, 'image.send', 'glance', '이미지 전송', 0, '이미지 전송 진행 중', '2025-01-14 06:55:25.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(64, 'image.update', 'glance', '이미지 생성 및 업데이트', 1, '이미지 스냅샷 생성 및 업데이트 완료', '2025-01-14 06:55:25.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(65, 'image.delete', 'glance', '이미지 삭제', 1, '이미지 삭제 완료', '2025-01-14 06:55:25.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(66, 'create', 'Nova', '인스턴스 생성', 0, '인스턴스 생성', '2025-01-14 08:49:14.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(67, 'network-vif-plugged', 'Nova', '네트워크 변경', 0, '네트워크 변경', '2025-01-14 09:32:50.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(68, 'network-changed', 'Nova', '네트워크 변경', 0, '네트워크 변경', '2025-01-14 09:32:50.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(69, 'network-vif-unplugged', 'Nova', '네트워크 변경', 0, '네트워크 변경', '2025-01-15 07:12:19.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(70, 'network-vif-deleted', 'Nova', '네트워크 변경', 0, '네트워크 변경', '2025-01-15 07:12:41.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(71, 'instance_resize', 'Nova', '유형변경', 9, '인스턴스 유형 변경', '2025-01-20 15:12:01.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(72, 'instance_modify', 'Nova', '인스턴스 수정', 9, '인스턴스 수정', '2025-01-20 15:12:01.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(73, 'instance_createImage', 'Nova', '인스턴스 스냅샷 생성', 9, '인스턴스 스냅샷 생성 (마스터)', '2025-01-20 15:12:01.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(74, 'instance_createConsole', 'Nova', '인스턴스 콘솔 생성', 9, '인스턴스 콘솔 생성', '2025-01-20 15:12:01.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(75, 'instance_create', 'Nova', '인스턴스 생성', 9, '인스턴스 생성', '2025-01-20 15:12:01.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(76, 'instance_live_migration', 'Nova', '라이브 마이그레이션', 9, 'Live 마이그레이션 ', '2025-02-14 15:12:01.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(77, 'instance_stop', 'Nova', '인스턴스 종료', 9, '인스턴스 종료', '2025-02-14 15:12:01.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(78, 'instance_attach_interface', 'Nova', '볼륨 추가', 9, '인스턴스 볼륨 추가', '2025-02-14 15:12:01.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(79, 'instance_hard_reboot', 'Nova', '하드 리부트', 9, '하드 리부트', '2025-02-14 15:12:01.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(80, 'instance_soft_reboot', 'Nova', '소프트 리부트', 9, '소프트 리부트', '2025-02-14 15:12:01.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(81, 'instance_cold_migration', 'Nova', '콜드 마이그레이션', 9, '콜드 마이그레이션', '2025-02-14 15:12:01.000');
INSERT INTO dp_common.cb_event_log_type
(id, event_type, component, display_name, last_step, description, created_at)
VALUES(82, 'instance_detach_interface', 'Nova', '인터페이스 연결해제', 9, '인터페이스 연결해제', '2025-02-14 15:12:01.000');




INSERT INTO dp_common.cb_baton_attr (`key`,value) VALUES
     ('collector_defPeriodSecMeta','60'),
     ('collector_defPeriodSecMetric','60'),
     ('opensearch_urls','[https://172.24.4.56:9200, https://172.24.4.56:9200, https://172.24.4.56:9200]'),
     ('opensearch_user_id','admin'),
     ('opensearch_user_pwd','admin'),
     ('collector_port_nic_port_defPeriodSec','30'),
     ('openstack.option.epname','public'),
     ('openstack.option.revtype','1'),
	 ('vault.use','1');
 
INSERT INTO dp_common.cb_code_group
(code, name, description, created_at, updated_at, deleted_at, deleted)
VALUES('Cisco.Api.Mode', 'CiscoApiMode', '시스코 api 모드', '2025-02-12 05:34:22.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_code_group
(code, name, description, created_at, updated_at, deleted_at, deleted)
VALUES('Host.Company', 'HostCompany', '호스트 제조사', '2025-02-12 05:33:47.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_code_group
(code, name, description, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.Company', 'SwitchCompany', '스위치 제조사', '2025-02-12 05:33:47.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_code_group
(code, name, description, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.dot1qVlanStaticRowStatus', 'VLANStatus', 'VLAN 상태', '2024-11-26 11:01:11.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_code_group
(code, name, description, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfAdminStatus', 'IfAdminStatus', '스위치 포트의 인터페이스 상태(관리자)', '2024-11-26 11:01:11.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_code_group
(code, name, description, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfOperStatus', 'IfOperStatus', '스위치 포트의 인터페이스 상태', '2024-11-26 11:01:11.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_code_group
(code, name, description, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', 'IANAifType', '스위치 포트의 인터페이스 타입', '2024-11-26 08:37:27.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_code_group
(code, name, description, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemChassisIdSubtype', 'ChassisIdSubtype', '스위치 세시 타입', '2024-11-27 06:19:19.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_code_group
(code, name, description, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemPortIdSubtype', 'PortIdSubtype', '스위치 peer 데이터 타입', '2024-11-27 06:19:19.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_code_group
(code, name, description, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.Status', 'SwitchStatus', '스위치 상태', '2024-11-26 11:01:11.000', NULL, NULL, 0);
 
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Cisco.Api.Mode', 'NX-OS', 'NX-OS', NULL, 0, '2025-02-12 05:36:58.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Cisco.Api.Mode', 'NX-OS(ACI)', 'NX-OS(ACI)', NULL, 0, '2025-02-12 05:36:58.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Host.Company', 'HPE', 'HPE', NULL, 0, '2025-02-12 05:36:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Host.Company', 'Intel', 'Intel', NULL, 0, '2025-02-12 05:36:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.Company', 'Cisco', 'Cisco', NULL, 0, '2025-02-12 05:36:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.Company', 'Dasan', 'Dasan', NULL, 0, '2025-02-12 05:36:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.Company', 'HPE', 'HPE', NULL, 0, '2025-02-12 05:36:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.Company', 'Juniper', 'Juniper', NULL, 0, '2025-02-12 05:36:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.dot1qVlanStaticRowStatus', '1', 'active', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.dot1qVlanStaticRowStatus', '2', 'notInService', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.dot1qVlanStaticRowStatus', '3', 'notReady', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.dot1qVlanStaticRowStatus', '4', 'createAndGo', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.dot1qVlanStaticRowStatus', '5', 'createAndWait', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.dot1qVlanStaticRowStatus', '6', 'destroy', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfAdminStatus', '1', 'up', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfAdminStatus', '2', 'down', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfAdminStatus', '3', 'testing', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfOperStatus', '1', 'up', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfOperStatus', '2', 'down', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfOperStatus', '3', 'testing', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfOperStatus', '4', 'unknown', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfOperStatus', '5', 'dormant', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfOperStatus', '6', 'notPresent', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfOperStatus', '7', 'lowerLayerDown', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '1', 'other', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '10', 'iso88026Man', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '100', 'voiceEM', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '101', 'voiceFXO', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '102', 'voiceFXS', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '103', 'voiceEncap', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '104', 'voiceOverIp', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '105', 'atmDxi', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '106', 'atmFuni', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '107', 'atmIma', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '108', 'pppMultilinkBundle', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '109', 'ipOverCdlc', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '11', 'starLan', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '110', 'ipOverClaw', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '111', 'stackToStack', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '112', 'virtualIpAddress', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '113', 'mpc', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '114', 'ipOverAtm', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '115', 'iso88025Fiber', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '116', 'tdlc', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '117', 'gigabitEthernet', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '118', 'hdlc', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '119', 'lapf', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '12', 'proteon10Mbit', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '120', 'v37', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '121', 'x25mlp', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '122', 'x25huntGroup', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '123', 'transpHdlc', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '124', 'interleave', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '125', 'fast', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '126', 'ip', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '127', 'docsCableMaclayer', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '128', 'docsCableDownstream', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '129', 'docsCableUpstream', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '13', 'proteon80Mbit', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '130', 'a12MppSwitch', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '131', 'tunnel', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '132', 'coffee', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '133', 'ces', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '134', 'atmSubInterface', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '135', 'l2vlan', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '136', 'l3ipvlan', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '137', 'l3ipxvlan', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '138', 'digitalPowerline', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '139', 'mediaMailOverIp', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '14', 'hyperchannel', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '140', 'dtm', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '141', 'dcn', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '142', 'ipForward', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '143', 'msdsl', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '144', 'ieee1394', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '145', 'if-gsn', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '146', 'dvbRccMacLayer', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '147', 'dvbRccDownstream', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '148', 'dvbRccUpstream', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '149', 'atmVirtual', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '15', 'fddi', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '150', 'mplsTunnel', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '151', 'srp', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '152', 'voiceOverAtm', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '153', 'voiceOverFrameRelay', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '154', 'idsl', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '155', 'compositeLink', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '156', 'ss7SigLink', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '157', 'propWirelessP2P', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '158', 'frForward', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '159', 'rfc1483', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '16', 'lapb', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '160', 'usb', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '161', 'ieee8023adLag', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '162', 'bgppolicyaccounting', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '163', 'frf16MfrBundle', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '164', 'h323Gatekeeper', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '165', 'h323Proxy', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '166', 'mpls', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '167', 'mfSigLink', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '168', 'hdsl2', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '169', 'shdsl', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '17', 'sdlc', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '170', 'ds1FDL', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '171', 'pos', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '172', 'dvbAsiIn', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '173', 'dvbAsiOut', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '174', 'plc', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '175', 'nfas', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '176', 'tr008', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '177', 'gr303RDT', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '178', 'gr303IDT', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '179', 'isup', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '18', 'ds1', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '180', 'propDocsWirelessMaclayer', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '181', 'propDocsWirelessDownstream', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '182', 'propDocsWirelessUpstream', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '183', 'hiperlan2', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '184', 'propBWAp2Mp', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '185', 'sonetOverheadChannel', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '186', 'digitalWrapperOverheadChannel', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '187', 'aal2', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '188', 'radioMAC', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '189', 'atmRadio', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '19', 'e1', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '190', 'imt', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '191', 'mvl', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '192', 'reachDSL', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '193', 'frDlciEndPt', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '194', 'atmVciEndPt', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '195', 'opticalChannel', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '196', 'opticalTransport', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '197', 'propAtm', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '198', 'voiceOverCable', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '199', 'infiniband', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '2', 'regular1822', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '20', 'basicISDN', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '200', 'teLink', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '201', 'q2931', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '202', 'virtualTg', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '203', 'sipTg', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '204', 'sipSig', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '205', 'docsCableUpstreamChannel', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '206', 'econet', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '207', 'pon155', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '208', 'pon622', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '209', 'bridge', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '21', 'primaryISDN', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '210', 'linegroup', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '211', 'voiceEMFGD', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '212', 'voiceFGDEANA', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '213', 'voiceDID', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '214', 'mpegTransport', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '215', 'sixToFour', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '216', 'gtp', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '217', 'pdnEtherLoop1', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '218', 'pdnEtherLoop2', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '219', 'opticalChannelGroup', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '22', 'propPointToPointSerial', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '220', 'homepna', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '221', 'gfp', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '222', 'ciscoISLvlan', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '223', 'actelisMetaLOOP', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '224', 'fcipLink', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '225', 'rpr', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '226', 'qam', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '227', 'lmp', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '228', 'cblVectaStar', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '229', 'docsCableMCmtsDownstream', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '23', 'ppp', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '230', 'adsl2', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '231', 'macSecControlledIF', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '232', 'macSecUncontrolledIF', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '233', 'aviciOpticalEther', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '234', 'atmbond', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '235', 'voiceFGDOS', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '236', 'mocaVersion1', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '237', 'ieee80216WMAN', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '238', 'adsl2plus', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '239', 'dvbRcsMacLayer', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '24', 'softwareLoopback', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '240', 'dvbTdm', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '241', 'dvbRcsTdma', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '242', 'x86Laps', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '243', 'wwanPP', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '244', 'wwanPP2', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '245', 'voiceEBS', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '246', 'ifPwType', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '247', 'ilan', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '248', 'pip', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '249', 'aluELP', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '25', 'eon', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '250', 'gpon', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '251', 'vdsl2', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '252', 'capwapDot11Profile', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '253', 'capwapDot11Bss', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '254', 'capwapWtpVirtualRadio', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '255', 'bits', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '256', 'docsCableUpstreamRfPort', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '257', 'cableDownstreamRfPort', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '258', 'vmwareVirtualNic', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '259', 'ieee802154', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '26', 'ethernet3Mbit', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '260', 'otnOdu', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '261', 'otnOtu', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '262', 'ifVfiType', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '263', 'g9981', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '264', 'g9982', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '265', 'g9983', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '266', 'aluEpon', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '267', 'aluEponOnu', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '268', 'aluEponPhysicalUni', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '269', 'aluEponLogicalLink', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '27', 'nsip', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '270', 'aluGponOnu', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '271', 'aluGponPhysicalUni', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '272', 'vmwareNicTeam', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '277', 'docsOfdmDownstream', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '278', 'docsOfdmaUpstream', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '279', 'gfast', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '28', 'slip', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '280', 'sdci', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '281', 'xboxWireless', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '282', 'fastdsl', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '283', 'docsCableScte55d1FwdOob', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '284', 'docsCableScte55d1RetOob', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '285', 'docsCableScte55d2DsOob', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '286', 'docsCableScte55d2UsOob', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '287', 'docsCableNdf', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '288', 'docsCableNdr', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '289', 'ptm', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '29', 'ultra', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '290', 'ghn', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '3', 'hdh1822', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '30', 'ds3', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '31', 'sip', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '32', 'frameRelay', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '33', 'rs232', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '34', 'para', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '35', 'arcnet', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '36', 'arcnetPlus', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '37', 'atm', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '38', 'miox25', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '39', 'sonet', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '4', 'ddnX25', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '40', 'x25ple', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '41', 'iso88022llc', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '42', 'localTalk', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '43', 'smdsDxi', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '44', 'frameRelayService', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '45', 'v35', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '46', 'hssi', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '47', 'hippi', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '48', 'modem', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '49', 'aal5', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '5', 'rfc877x25', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '50', 'sonetPath', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '51', 'sonetVT', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '52', 'smdsIcip', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '53', 'propVirtual', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '54', 'propMultiplexor', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '55', 'ieee80212', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '56', 'fibreChannel', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '57', 'hippiInterface', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '58', 'frameRelayInterconnect', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '59', 'aflane8023', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '6', 'ethernetCsmacd', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '60', 'aflane8025', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '61', 'cctEmul', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '62', 'fastEther', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '63', 'isdn', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '64', 'v11', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '65', 'v36', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '66', 'g703at64k', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '67', 'g703at2mb', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '68', 'qllc', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '69', 'fastEtherFX', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '7', 'iso88023Csmacd', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '70', 'channel', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '71', 'ieee80211', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '72', 'ibm370parChan', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '73', 'escon', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '74', 'dlsw', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '75', 'isdns', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '76', 'isdnu', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '77', 'lapd', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '78', 'ipSwitch', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '79', 'rsrb', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '8', 'iso88024TokenBus', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '80', 'atmLogical', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '81', 'ds0', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '82', 'ds0Bundle', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '83', 'bsc', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '84', 'async', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '85', 'cnr', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '86', 'iso88025Dtr', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '87', 'eplrs', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '88', 'arap', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '89', 'propCnls', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '9', 'iso88025TokenRing', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '90', 'hostPad', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '91', 'termPad', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '92', 'frameRelayMPI', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '93', 'x213', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '94', 'adsl', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '95', 'radsl', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '96', 'sdsl', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '97', 'vdsl', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '98', 'iso88025CRFPInt', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.IfType', '99', 'myrinet', '', 0, '2024-11-26 10:44:35.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemChassisIdSubtype', '1', 'chassisComponent', NULL, 0, '2024-11-27 06:22:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemChassisIdSubtype', '2', 'interfaceAlias', NULL, 0, '2024-11-27 06:22:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemChassisIdSubtype', '3', 'portComponent', NULL, 0, '2024-11-27 06:22:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemChassisIdSubtype', '4', 'macAddress', NULL, 0, '2024-11-27 06:22:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemChassisIdSubtype', '5', 'networkAddress', NULL, 0, '2024-11-27 06:22:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemChassisIdSubtype', '6', 'interfaceName', NULL, 0, '2024-11-27 06:22:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemChassisIdSubtype', '7', 'local', NULL, 0, '2024-11-27 06:22:57.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemPortIdSubtype', '1', 'interfaceAlias', NULL, 0, '2024-11-27 06:22:58.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemPortIdSubtype', '2', 'portComponent', NULL, 0, '2024-11-27 06:22:58.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemPortIdSubtype', '3', 'macAddress', NULL, 0, '2024-11-27 06:22:58.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemPortIdSubtype', '4', 'networkAddress', NULL, 0, '2024-11-27 06:22:58.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemPortIdSubtype', '5', 'interfaceName', NULL, 0, '2024-11-27 06:22:58.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.lldpRemPortIdSubtype', '6', 'local', NULL, 0, '2024-11-27 06:22:58.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.Status', 'down', 'down', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);
INSERT INTO dp_common.cb_common_code
(group_code, code, name, description, sort_seq, created_at, updated_at, deleted_at, deleted)
VALUES('Switch.Status', 'up', 'up', NULL, 0, '2024-11-26 11:08:39.000', NULL, NULL, 0);

commit;