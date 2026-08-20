#!/usr/bin/env bash

nerdctl compose -f docker-compose.yaml down
nerdctl compose -f middleware-compose.yaml down

service_list=("mariadb" "redis" "vault" "oauth2-proxy" "oauth2-redis" "keycloak" "mariadb-keycloak" "kafka" "zookeeper" "maestro-auth-gateway" "maestro-admin-common-api" "contrabass-api" "contrabass-remote-app" "maestro-remote-app" "maestro-host-app" "nginx" "maestro-registry" "cloud-service-collector" "contrabass-scheduler" "maestro-iam-adapter-api" "maestro-event-pusher" "cloud-service-api" "notification-adapter-api")

services=23

for service in "${service_list[@]}";do
  res=$(nerdctl ps | awk '{print $NF}' | grep -xc $service)
  if [[ "$res" -ne 1 ]];then
    services=$((services - 1))
  else
    exit 1
  fi
done

if [[ "$services" -eq 0 ]];then
 echo
 echo -e "contrabass has been stopped"
fi
