
set foreign_key_checks = 0;
use maestro;
delete from maestro.MSTR_SOLUTION_SERVER where id = '3b21c93a-1665-11ef-922c-16fe18334070';

insert into maestro.MSTR_SOLUTION_SERVER values
    ('3b21c93a-1665-11ef-922c-16fe18334070', 'pipeline-app', 1, null, null, null, null, null, 'eeffe021-b1f6-11ee-b0d1-0242ac110002', 1, '/v1/trombone/pipeline/app', '/api-docs', 'app 서버');



create table maestro.MSTR_LOG_TAG_API_DATA
(
    id           varchar(255) default uuid() not null
        primary key,
    solution     varchar(255)                null,
    log_tag_name varchar(255)                null,
    method       varchar(255)                null,
    server_name  varchar(255)                null,
    path         varchar(255)                null,
    description  varchar(255)                null,
    create_time  timestamp                   null
)
    comment '로그태그 최초 세팅용 데이터. 환경별로 api id가 다를 수 있기 때문에 사용한다.';

insert into maestro.MSTR_LOG_TAG_API_DATA (id, solution, log_tag_name, method, server_name, path, description, create_time)
values  ('711a04bc-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/pipeline/workflow/executeWorkFlow', '파이프라인 실행 api', '2024-05-27 00:00:00'),
        ('711b8dfd-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/project/create', 'trombone 파이프라인 생성 api', '2024-05-27 00:00:00'),
        ('711d17f2-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/project/update', 'trombone 파이프라인 수정 api', '2024-05-27 00:00:00'),
        ('711eac78-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/project/delete', 'trombone 파이프라인 삭제 api', '2024-05-27 00:00:00'),
        ('71203e59-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/pipeline/workflow/create', 'trombone 파이프라인 구성 저장 api', '2024-05-27 00:00:00'),
        ('71221fd4-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/build/create', 'trombone 빌드 생성', '2024-05-27 00:00:00'),
        ('71236aab-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/build/update', 'trombone 빌드 수정', '2024-05-27 00:00:00'),
        ('71252094-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/build/delete', 'trombone 빌드 삭제', '2024-05-27 00:00:00'),
        ('7126b2f2-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/deploy/create', 'trombone 배포 생성 api', '2024-05-27 00:00:00'),
        ('7128548d-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/deploy/update', 'trombone 배포 수정 api', '2024-05-27 00:00:00'),
        ('7129fd3e-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/deploy/delete', 'trombone 배포 삭제 api', '2024-05-27 00:00:00'),
        ('712b9a6a-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/sparrow/create', 'trombone 정적분석 생성 api', '2024-05-27 00:00:00'),
        ('712d3036-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/sparrow/update', 'trombone 정적분석 수정 api', '2024-05-27 00:00:00'),
        ('712ea5cb-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/sparrow/delete', 'trombone 정적분석 삭제 api', '2024-05-27 00:00:00'),
        ('712ff76d-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/scheduled-deployment/create', 'trombone 예약 배포 생성 api', '2024-05-27 00:00:00'),
        ('71315a12-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/scheduled-deployment/update/{deployment-id}', 'trombone 예약 배포 수정 api', '2024-05-27 00:00:00'),
        ('7132bca9-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/scheduled-deployment/delete/{deployment-id}', 'trombone 예약 배포 삭제 api', '2024-05-27 00:00:00'),
        ('713415ae-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/cluster/create', 'trombone 클러스터 토큰 생성 api', '2024-05-27 00:00:00'),
        ('71356419-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/cluster/update', 'trombone 클러스터 토큰 수정 api', '2024-05-27 00:00:00'),
        ('7136d561-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/cluster/delete', 'trombone 클러스터 토큰 삭제 api', '2024-05-27 00:00:00'),
        ('71384eea-1d76-11ef-922c-16fe18334070', 'Trombone', '파이프라인 이벤트', 'POST', 'pipeline-app', '/api/security/update', 'trombone 보안 정책 관리 수정 api', '2024-05-27 00:00:00'),
        ('8c783a1b-18d3-11ef-922c-16fe18334070', 'CMP', '서비스 신청', 'POST', 'user-common', '/service-objects/requests', '서비스 신청', '2024-05-03 00:00:00'),
        ('8c79e951-18d3-11ef-922c-16fe18334070', 'CMP', '서비스 신청', 'POST', 'user-common', '/service-objects/requests/{id}/approve', '서비스 신청 승인', '2024-05-03 00:00:00'),
        ('8c7b596e-18d3-11ef-922c-16fe18334070', 'CMP', '서비스 신청', 'POST', 'user-common', '/service-objects/requests/{id}/reject', '서비스 신청 반려', '2024-05-03 00:00:00'),
        ('8c7cc355-18d3-11ef-922c-16fe18334070', 'CMP', '서비스 신청', 'PUT', 'user-common', '/service-objects/requests/{id}', '서비스 신청 취소', '2024-05-03 00:00:00'),
        ('8c7e15b6-18d3-11ef-922c-16fe18334070', 'CMP', '서비스 신청', 'POST', 'admin-common', '/service-objects/requests/{id}/provisions/by-config-map', '서비스 신청 실행', '2024-05-03 00:00:00'),
        ('97e1dccf-1d8c-11ef-922c-16fe18334070', 'CMP', '과금 관리', 'PUT', 'admin-finops', '/post/put/{id}', '플랫폼 과금 정책 사용여부 수정', '2024-05-13 00:00:00'),
        ('97e37be8-1d8c-11ef-922c-16fe18334070', 'CMP', '과금 관리', 'PUT', 'admin-finops', '/post/delete/{id}', '플랫폼 과금 정책 삭제', '2024-05-13 00:00:00'),
        ('97e65ade-1d8c-11ef-922c-16fe18334070', 'CMP', '과금 관리', 'POST', 'admin-finops', '/post/finops', '플랫폼 과금 정책 저장', '2024-05-13 00:00:00'),
        ('97e8efa1-1d8c-11ef-922c-16fe18334070', 'CMP', '과금 관리', 'POST', 'admin-finops', '/post/finops/batch', '플랫폼 과금 정책 일괄 저장', '2024-05-13 00:00:00'),
        ('97ea93f5-1d8c-11ef-922c-16fe18334070', 'CMP', '과금 관리', 'PUT', 'admin-finops', '/post/other/put/{folderId}', '기타 과금 정책 수정', '2024-05-13 00:00:00'),
        ('97ecfcb3-1d8c-11ef-922c-16fe18334070', 'CMP', '과금 관리', 'PUT', 'admin-finops', '/post/other/delete/{folderId}', '기타 과금 정책 삭제', '2024-05-13 00:00:00'),
        ('97ef6fb5-1d8c-11ef-922c-16fe18334070', 'CMP', '과금 관리', 'POST', 'admin-finops', '/post/other/finops', '기타 과금 정책 저장', '2024-05-13 00:00:00');
