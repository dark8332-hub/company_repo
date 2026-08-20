#!/usr/bin/env bash

# P_DOMAIN=localhost
# P_PORT=8080
# DOMAIN=localhost
# PORT=9000

modifyEnvs () {
# modify configs
CONFIG_FILES=$(find ./config -type f -exec echo {} \;)

for f in $CONFIG_FILES;do
    sed -i "s|$P_DOMAIN:$P_PORT|$DOMAIN:$PORT|g" $f
    sed -i "s|$P_DOMAIN|$DOMAIN|g" $f
    sed -i "s|server_name $P_DOMAIN|server_name $DOMAIN|g" $f
    sed -i "s|X-Forwarded-Port $P_PORT|X-Forwarded-Port $PORT|g" $f
    sed -i "s|http-port=$P_PORT|http-port=$PORT|g" $f
    sed -i "s|listen $P_PORT|listen $PORT|g" $f
    sed -i "s|keycloak:$P_PORT|keycloak:$PORT|g" $f
    sed -i "s|$DOMAIN:5555/nginx|localhost:5555/nginx|g" $f

done

COMPOSE_FILES=$(find . -name "*.yaml" -type f -exec echo {} \;)
for f in $COMPOSE_FILES;do
    sed -i "s|$P_PORT:$P_PORT|$PORT:$PORT|g" $f
    sed -i "s|$P_PORT #keycloak|$PORT #keycloak|g" $f
    sed -i "s|HOST: $P_DOMAIN|HOST: $DOMAIN|g" $f
    sed -i "s|$P_DOMAIN:$P_PORT|$DOMAIN:$PORT|g" $f
    sed -i "s|keycloak:$P_PORT|keycloak:$PORT|g" $f
done
}

## frontend config - ==[[domain]]
## oauth2-proxy.cfg - ==[[domain]]
## docker-compose - nginx args HOST, ==oauth2-proxy login-url, ==whitelist-domain - [[domain]]
## keycloak keycloak.conf, realm.json - ==[[domain]]