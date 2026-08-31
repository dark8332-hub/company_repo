# OKESTRO OpenStack Operations Platform

OpenStack 운영 엔지니어를 위한 일일점검 및 모니터링 대시보드입니다.

## 빠른 실행

Docker Compose가 설치된 서버에서 다음 명령을 실행합니다.

```bash
docker compose up -d --build
```

실행 후 `http://<서버 주소>:9080`으로 접속합니다.

## 운영 명령

```bash
# 상태 확인
docker compose ps

# 로그 확인
docker compose logs -f dashboard

# 재시작
docker compose restart dashboard

# 종료
docker compose down
```

## 이미지 파일로 전달

인터넷에 연결된 빌드 환경에서 이미지를 생성합니다.

```bash
docker build -t okestro/openstack-ops-platform:latest .
docker save okestro/openstack-ops-platform:latest | gzip > openstack-ops-platform.tar.gz
```

대상 서버로 파일을 전달한 뒤 실행합니다.

```bash
docker load -i openstack-ops-platform.tar.gz
docker run -d \
  --name openstack-ops-platform \
  --restart unless-stopped \
  -p 9080:9080 \
  okestro/openstack-ops-platform:latest
```

## 구성 파일

- `index.html`: 대시보드 화면 구조
- `styles.css`: OKESTRO 남색 테마 및 반응형 스타일
- `app.js`: 화면 동작
- `provider.html`: 공급자 VIP 연결 및 호스트 검색 화면
- `provider.js`: SSH 연결 및 검색 화면 동작
- `server.py`: SSH 검색 API와 정적 화면 제공
- `provider_store.py`: 공급자 인증정보 암호화 저장, 점검 이력·요약·예약 설정 관리
- `inspection_report.py`: 점검 내용 PDF 생성(fpdf2)
- `fonts/`: PDF 한글 출력용 NanumGothic 글꼴(OFL 라이선스)
- `nginx.conf`: 배포용 웹 서버 설정
- `Dockerfile`: 컨테이너 이미지 정의
- `compose.yaml`: 운영 실행 구성
- `PROGRESS.md`: 프로젝트 진행 기록

## 점검 내용 PDF 저장

일일점검 화면의 `점검 내용 보기`에서 `PDF 저장`을 누르면 화면에 표시된 전체 점검 내용이 서버에서 PDF로 생성되어 `일일점검_<공급자>_<날짜-시각>.pdf` 파일로 바로 내려받아집니다. 한글 글꼴은 이미지에 포함된 `fonts/` 디렉터리의 NanumGothic을 사용합니다.

## 일일점검 예약 실행

일일점검 화면의 `예약 실행` 패널에서 공급자별로 매일 실행할 시각과 점검 항목을 저장하면 서버가 해당 시각에 자동으로 점검을 실행하고 알림을 갱신합니다. 시각은 `INSPECTION_TIMEZONE` 환경 변수(기본 `Asia/Seoul`)를 기준으로 해석하며 `compose.yaml`에서 변경할 수 있습니다. 예약 결과는 점검 이력에 `예약` 구분으로 기록되고, 같은 공급자의 점검이 이미 실행 중이면 해당 날짜의 예약 실행은 건너뜁니다.

## 공급자 데이터 보관

등록된 공급자와 점검 이력은 컨테이너의 `/app/data/providers.db`에 저장됩니다. SSH 개인키와 비밀번호는 `/app/data/.master_key`로 암호화되며 API와 화면에 반환되지 않습니다.

VIP가 다른 Controller로 이동해 SSH 호스트 키가 달라진 경우 공급자를 다시 등록하지 않습니다. 공급자 화면의 `SSH 키 관리`에서 현재 지문을 조회하고 대상 Controller에서 직접 확인한 값과 일치할 때만 신뢰 목록에 추가합니다. 승인 전에는 SSH 사용자 인증을 시도하지 않으며 지문 승인과 폐기 이력이 데이터베이스에 기록됩니다.

Compose 실행 시 `provider-data` 볼륨이 연결되므로 컨테이너를 재시작하거나 교체해도 데이터가 유지됩니다. 백업할 때는 데이터베이스와 암호화 키를 반드시 함께 보관해야 합니다.

```bash
docker run --rm \
  -v openstack-ops-platform_provider-data:/data \
  -v "$PWD":/backup \
  alpine tar -czf /backup/provider-data-backup.tar.gz -C /data .
```
