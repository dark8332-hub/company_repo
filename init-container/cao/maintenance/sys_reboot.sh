# 시스템 재기동 되었을때 실행
nerdctl compose -f ../docker-compose.yaml down
sleep 5
nerdctl compose -f ../middleware-compose.yaml down
sleep 5

nerdctl compose -f ../middleware-compose.yaml up -d
sleep5
nerdctl compose -f ../docker-compose.yaml up -d
