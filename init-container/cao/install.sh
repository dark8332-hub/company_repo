#!/usr/bin/env bash

# NAME="Rocky Linux"
# VERSION="9.3 (Blue Onyx)"
# ID="rocky"
# ID_LIKE="rhel centos fedora"
# VERSION_ID="9.3"
# PLATFORM_ID="platform:el9"
# PRETTY_NAME="Rocky Linux 9.3 (Blue Onyx)"

start_time=$(date +%s)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ./config.sh

################## domain & port ######################
## as-is
P_DOMAIN=contrabass.os
P_PORT=9443
## to-be
DOMAIN=contrabass.os
PORT=9443
#######################################################

# "P_DOMAIN" 문자열을 포함하는 파일을 찾고 "P_DOMAIN"를 "DOMAIN"로 변경
find . -type f ! -name "*.tar" ! -name "*.tar.gz" ! -name "*.tgz" -exec grep -l "$P_DOMAIN" {} + | while read -r file; do
    sed -i "s|$P_DOMAIN|$DOMAIN|g" "$file"
done

# "P_PORT" 문자열을 포함하는 파일을 찾고 "P_PORT"를 "PORT"로 변경
find . -type f ! -name "*.tar" ! -name "*.tar.gz" ! -name "*.tgz" -exec grep -l "$P_PORT" {} + | while read -r file; do
    sed -i "s|$P_PORT|$PORT|g" "$file"
done

# check requirements and install

##필요한 디렉토리 생성
directories="/opt/cni/bin /etc/containerd /etc/nerdctl /etc/buildkit /etc/cni.net.d"

###디렉토리 존재 유무 체크 후 없으면 생성
for dir in $directories; do
    if [ ! -d "$dir" ]; then
        echo "디렉토리 $dir 생성 중..."
        mkdir -p "$dir"
        chmod 755 "$dir"
        echo "디렉토리 $dir가 생성되었습니다."
    else
        echo "디렉토리 $dir는 이미 존재합니다."
        echo "디렉토리 생성 작업을 스킵합니다."
    fi
done

## check containerd
if ! command -v containerd -v &> /dev/null;then
    echo "installing nerdctl"
    tar zxvf containerd-1.7.20-linux-amd64.tar.gz -C /usr/local/

    echo "[INFO] containerd setting...."
cat << EOF > /etc/systemd/system/containerd.service
# Copyright The containerd Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     <http://www.apache.org/licenses/LICENSE-2.0>
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target
[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
LimitMEMLOCK=infinity
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999
# Set the cgroup slice of the service so that kube reserved takes effect
[Install]
WantedBy=multi-user.target
EOF
### containerd service enable
systemctl daemon-reload
systemctl enable --now containerd.service
containerd config default | sudo tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd.service
    else
	    echo "[INFO] already installed containerd"
    fi


## nerdctl && nerdctl compose
echo "installing nerdctl & nerdctl compose..."

if ! command -v nerdctl &> /dev/null;then 
    tar xvf nerdctl-1.5.0-linux-amd64.tar.gz
    tar zxvf buildkit-v0.17.0.linux-amd64.tar.gz -C /usr/local/
    mv ./nerdctl /usr/local/bin/
    cat << EOF > /etc/nerdctl/nerdctl.toml
debug             = false
debug_full        = false
address           = "unix:///var/run/containerd/containerd.sock"
snapshotter       = "overlayfs"
cni_path          = "/opt/cni/bin"
cni_netconfpath   = "/etc/cni/net.d"
cgroup_manager    = "systemd"
hosts_dir         = ["/etc/containerd/certs.d"]
EOF

    cat << EOF > /etc/systemd/system/buildkit.service
[Unit]
Description=BuildKit Daemon
After=network.target

[Service]
ExecStart=/usr/local/bin/buildkitd
Restart=always

[Install]
WantedBy=multi-user.target

EOF
    export BUILDKIT_HOST=unix:///run/buildkit/buildkitd.sock
    sudo systemctl daemon-reload
    sudo systemctl enable --now buildkit
    sudo systemctl restart containerd.service
    mkdir -p /etc/buildkit
    echo -e "[worker.oci]\n\tenabled = false\n[worker.containerd]\n\tenabled = true" | tee /etc/buildkit/buildkitd.toml

    nerdctl version
else
    nerdctl version
fi

if [ ! -d /opt/cni/bin ]; then
	mkdir -p /opt/cni/bin
	#tar Cxzvvf /opt/cni/bin cni-plugins-linux-amd64-v1.1.1.tgz
	tar Cxzvvf /opt/cni/bin cni-plugins-linux-amd64-v1.3.0.tgz
fi

if [ ! -f /usr/local/bin/runc ]; then
	echo "[INFO] installing runc..."
	install -m 755 ./runc.amd64 /usr/local/bin/runc
fi


if [ -z "$(nerdctl ps | grep maestro-registry)" ]; then
    echo "installing private registry..."
    sudo chmod -R 775 $DIR/registry/auth
    
    export CNI_PATH=/opt/cni/bin

    nerdctl load -i $DIR/artifacts/registry_3.0.0-alpha.1.tar

    nerdctl run -d -p 5555:5000 --restart always --name maestro-registry \
        -v "$(pwd)"/registry/auth:/auth \
        -v registry-data:/var/lib/registry \
        -e "REGISTRY_AUTH=htpasswd" \
        -e "REGISTRY_AUTH_HTPASSWD_REALM=maestro" \
        -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
        localhost:5000/registry:3.0.0-alpha.1
fi

# check status
if [ -z "$(nerdctl ps | grep maestro-registry)" ]; then
    echo "private registry has not set yet."
    echo "==================================="
    echo " Run "init.sh" again.      "
    echo "================================="
    echo " Run. "
    bash ./install.sh
    exit 1
fi

sleep 20

# nerdctl login
echo "login to the registry..."
echo "cloud1234" | nerdctl login localhost:5555 -u admin --password-stdin

# image load and push
echo "load images....."

rm -rf err_load.log > /dev/null
FILES="$DIR/artifacts/*"

for f in $FILES
do
  tar=$(echo "$f" | awk -F/ '{print $NF}')
  nerdctl load -i artifacts/$tar
  if [ $? -ne 0 ]; then
    echo "[`date`] Error:: failed to load: $tar" >> err_load.log 2>&1
    exit 1
  else
    echo "$tar has been loaded"
  fi
done


echo "and push to the registry..."


rm -rf err.log > /dev/null

images_output=$(nerdctl images)

IFS=$'\n' read -rd '' -a lines <<<"$images_output"

keep_tags=("kafka" "zookeeper" "busybox" "mariadb" "nginx" "oauth2-proxy" "redis" "registry" "vault" "opensearch" "opensearch-dashboard")

for ((i=1; i<${#lines[@]}; i++)); do

    line=${lines[$i]}
    IFS=' ' read -r -a parts <<<"$line"

    repository=${parts[0]}

    tag=${parts[1]}

    image_name=$(echo "$repository" | awk -F '/' '{print $NF}')

    new_tag="localhost:5555/$image_name:v1.0.1"

    for keep in "${keep_tags[@]}"; do
        if [[ "$image_name" == "$keep" ]]; then
            new_tag="localhost:5555/$image_name:$tag"
            break
        fi
    done

    if [[ "$image_name" == "keycloak" ]]; then
        new_tag="localhost:5555/$image_name:20.0.2"
    fi

    nerdctl tag "$repository:$tag" "$new_tag"

    nerdctl push "$new_tag"
    echo "Pushed image : $new_tag"

    if [[ "$new_name" == "" || ! "$new_name" =~ ":" ]]; then
    	#echo "Invalid new_name format: $new_name"
    	#echo "[`date`] Error:: Invalid new_name format: $new_name" >> err.log 2>&1
    	continue
    else
        echo "$new_tag: created and pushed to the registry"
    fi
done

# Delete unused images

images_output=$(nerdctl images)

IFS=$'\n' read -rd '' -a lines <<<"$images_output"

for ((i=1; i<${#lines[@]}; i++)); do

    line=${lines[$i]}
    IFS=' ' read -r -a parts <<<"$line"

    repository=${parts[0]}
    tag=${parts[1]}

    if [[ "$repository" == localhost:5555* ]]; then
        continue
    fi

    if [[ "$repository:$tag" == "localhost:5000/registry:3.0.0-alpha.1" ]]; then
        continue
    fi

    nerdctl rmi "$repository:$tag"

    if [ $? -ne 0 ]; then
        echo "[`date`] Error:: failed to delete image: $repository:$tag" >> err.log 2>&1
    else
        echo "$repository:$tag: deleted successfully"
    fi
done

# nerdctl create network maestro
nerdctl network create --subnet 30.4.0.0/23 maestro

# chmod configs
sudo chmod -R 775 $DIR/config

# modify configs
modifyEnvs

# install container to change file mode
nerdctl compose -f chmod.yaml up -d

# install middleware
## vault mariadb redis keycloak oauth2-proxy
echo "installing middlewares..."

mkdir -p /cao_db
chmod 777 /cao_db

if [ -d "/cao_db" ]; then
    rm -rf /cao_db
    mkdir -p /cao_db
fi

cp -r ./config/mariadb/initdb.d/* /cao_db

echo "===================================="
echo "Databases replication was successful."
echo "===================================="

sleep 10
nerdctl compose -f middleware-compose.yaml up -d

sleep 30
# check status
if [ -z "$(nerdctl ps | grep vault)" ] || [ -z "$(nerdctl ps | grep mariadb)" ] || [ -z "$(nerdctl ps | grep redis)" ] || [ -z "$(nerdctl ps | grep oauth2-proxy)" ] || [ -z "$(nerdctl ps | grep keycloak)" ]; then
    echo "something went wrong...\n"
    nerdctl compose -f middleware-compose.yaml down
    echo "try to restart service."
    nerdctl compose -f middleware-compose.yaml up -d
    #exit 1
else
    echo "middlewares all have been deployed successfully!"
fi
sleep 10
bash sql_injection.sh
sleep 5

# initialize vault
echo "initializing vault..."
nerdctl compose -f vault-init.yaml up -d

sleep 30
# extract root token from vault
nerdctl cp vault:/vault/data/secret.txt $DIR/config/vault/secret.env
sudo chmod 775 $DIR/config/vault/secret.env
echo "VAULT_TOKEN=$(grep '^SERVICE_VAULT_ROOT_TOKEN=' ./config/vault/secret.env | cut -d '=' -f2)" >> ./config/vault/secret.env
echo "BATON_VAULT_TOKEN=$(grep '^SERVICE_VAULT_ROOT_TOKEN=' ./config/vault/secret.env | cut -d '=' -f2)" >> ./config/vault/secret.env
echo "VAULT_ROOT_TOKEN=$(grep '^SERVICE_VAULT_ROOT_TOKEN=' ./config/vault/secret.env | cut -d '=' -f2)" >> ./config/vault/secret.env

# install auth & products
echo "installing products..."
nerdctl compose -f docker-compose.yaml up -d


# check if all of the application are ready!
service_list=("redis" "vault" "oauth2-proxy" "oauth2-redis" "keycloak" "mariadb-keycloak" "kafka" "zookeeper" "mariadb" "maestro-auth-gateway" "maestro-admin-common-api" "contrabass-api" "contrabass-remote-app" "maestro-remote-app" "maestro-host-app" "nginx" "maestro-registry" "cloud-service-collector" "contrabass-scheduler" "contrabass-admin-service" "maestro-iam-adapter-api" "maestro-event-pusher" "cloud-service-api" "notification-adapter-api" "pds-integration-service")
services=0
for service in "${service_list[@]}";do
  res=$(nerdctl ps | awk '{print $NF}' | grep -xc $service)
  if [[ "$res" -ne 1 ]];then
    echo "$service is down"
    echo "try to restart $service"
    #nerdctl compose -f docker-compose.yaml up -d
    #exit 1
  else
    services=$((services + 1))
  fi
done


end_time=$(date +%s)
execution_time=$((end_time - start_time))
minutes=$((execution_time / 60))
seconds=$((execution_time % 60))
echo "Total execution time: ${minutes}m ${seconds}s"

if [[ "$services" -eq 25 ]];then
 echo
 echo -e "=====================================================================\n contrabass All In One version has been deployed successfully!!! \n=====================================================================\n"
fi

