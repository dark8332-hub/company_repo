#!/bin/bash

# 네임스페이스 및 파드 이름 설정
CONTAINERD_NAME="mariadb"

# 적용할 디렉토리 리스트 설정
SQL_DIRECTORIES=(
    "/cao_db/00_init.sql"
#   "/cao_db/01_keycloak_ddl_single.sql"
    "/cao_db/02_cmp_cloud_service_ddl.sql"
    "/cao_db/03_cmp_ddl.sql"
    "/cao_db/04_cmp_dml.sql"
    "/cao_db/05_dp_common_ddl.sql"
    "/cao_db/06_dp_common_dml.sql"
    "/cao_db/07_contrabass.sql"
    "/cao_db/08_dp_common.sql"
    "/cao_db/09_dp_common_init.sql"
    "/cao_db/10_drs.sql"
)
# 컨테이너 내에서 SQL 적용 함수
sql_apply_sql() {
    local file_path="$1"
    echo "Applying $file_path..."
    nerdctl exec -i $CONTAINERD_NAME -- mariadb -uroot -pokestro2018 < "$file_path"
}


# 각 디렉토리의 SQL 파일을 순차적으로 실행
for dir in "${SQL_DIRECTORIES[@]}"; do
    for sql_file in $dir; do
        if [[ -f "$sql_file" ]]; then
            sql_apply_sql "$sql_file"
        else
            echo "SQL 파일이 존재하지 않음: $sql_file"
        fi
    done
done

nerdctl exec -i mariadb-keycloak -- mariadb -ukeycloak -pkeycloak < /cao_db/01_keycloak_ddl_single.sql

