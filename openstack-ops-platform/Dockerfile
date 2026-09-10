FROM python:3.12-slim
ARG APP_VERSION
ARG VCS_REF=unknown
ARG BUILD_TIME
ARG SOURCE_DIRTY=true
LABEL org.opencontainers.image.version=$APP_VERSION \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.created=$BUILD_TIME
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 서버가 import 하는 모듈 전부. 하나라도 빠지면 기동 즉시 ImportError 로 죽는다.
COPY server.py provider_store.py inspection_report.py inspection_excel.py runbooks.py inventory_collector.py ssh_privileges.py store_schema.py app_metadata.py ./
COPY VERSION ./
RUN python -c 'import json,os,pathlib; v=os.environ.get("APP_VERSION") or pathlib.Path("VERSION").read_text().strip(); pathlib.Path("VERSION").write_text(v+"\n"); pathlib.Path("build-info.json").write_text(json.dumps(dict(version=v,revision=os.environ.get("VCS_REF","unknown"),built_at=os.environ.get("BUILD_TIME",""),source_dirty=os.environ.get("SOURCE_DIRTY","true")=="true")))'
COPY index.html login.html styles.css login.js ./
COPY fonts ./fonts
COPY js ./js

# 공급자 DB 와 마스터 키가 사는 곳. 볼륨을 붙이지 않으면 컨테이너와 함께 사라진다.
VOLUME ["/app/data"]

EXPOSE 8090

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8090/api/health')" || exit 1

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8090", "--no-server-header"]
