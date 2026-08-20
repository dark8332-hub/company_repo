#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# chmod configs
sudo chmod -R 775 $DIR/config

# install container to change file mode
nerdctl compose -f chmod.yaml up -d

# install middleware
## vault mariadb redis keycloak oauth2-proxy
echo "installing middlewares..."

sleep 10
nerdctl compose -f middleware-compose.yaml up -d

sleep 30
# check status
if [ -z "$(nerdctl ps | grep vault)" ] || [ -z "$(nerdctl ps | grep mariadb)" ] || [ -z "$(nerdctl ps | grep redis)" ] || [ -z "$(nerdctl ps | grep oauth2-proxy)" ] || [ -z "$(nerdctl ps | grep keycloak)" ]; then
    echo "something went wrong..."
    nerdctl compose -f middleware-compose.yaml down
    exit 1
else
    echo "middlewares all have been deployed successfully!"
fi

# initialize vault
echo "initializing vault..."
nerdctl compose -f vault-init.yaml up -d

sleep 30
# extract root token from vault
nerdctl cp vault:/vault/data/secret.txt $DIR/config/vault/secret.env
sudo chmod 775 $DIR/config/vault/secret.env

# install auth & products
echo "installing products..."
nerdctl compose -f docker-compose.yaml up -d


# check if all of the application are ready!
service_list=("mariadb" "redis" "vault" "oauth2-proxy" "oauth2-redis" "keycloak" "mariadb-keycloak" "kafka" "zookeeper" "maestro-auth-gateway" "maestro-admin-common-api" "contrabass-api" "contrabass-remote-app" "maestro-remote-app" "maestro-host-app" "nginx" "maestro-registry" "cloud-service-collector" "contrabass-scheduler" "maestro-iam-adapter-api" "maestro-event-pusher" "cloud-service-api" "notification-adapter-api")

services=0
for service in "${service_list[@]}";do
  res=$(nerdctl ps | awk '{print $NF}' | grep -xc $service)
  if [[ "$res" -ne 1 ]];then
    echo "$service is down"
    exit 1
  else
    services=$((services + 1))
  fi
done

if [[ "$services" -eq 23 ]];then
 echo
 echo -e "=====================================================================\n contrabass - standalone version has been deployed successfully!!! \n=====================================================================\n"
fi
