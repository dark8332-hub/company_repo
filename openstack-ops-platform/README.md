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
- `provider_store.py`: 공급자 인증정보 암호화 저장 및 점검 이력 관리
- `nginx.conf`: 배포용 웹 서버 설정
- `Dockerfile`: 컨테이너 이미지 정의
- `compose.yaml`: 운영 실행 구성
- `PROGRESS.md`: 프로젝트 진행 기록

## 공급자 데이터 보관

등록된 공급자와 점검 이력은 컨테이너의 `/app/data/providers.db`에 저장됩니다. SSH 개인키와 비밀번호는 `/app/data/.master_key`로 암호화되며 API와 화면에 반환되지 않습니다.

Compose 실행 시 `provider-data` 볼륨이 연결되므로 컨테이너를 재시작하거나 교체해도 데이터가 유지됩니다. 백업할 때는 데이터베이스와 암호화 키를 반드시 함께 보관해야 합니다.

```bash
docker run --rm \
  -v openstack-ops-platform_provider-data:/data \
  -v "$PWD":/backup \
  alpine tar -czf /backup/provider-data-backup.tar.gz -C /data .
```
