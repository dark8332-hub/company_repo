#!/usr/bin/env sh

NOW=$(date +%Y%m%d-%H%M%S)

init() {
  vault operator init -key-shares=1 -key-threshold=1 -format=json > /vault/data/vault_init_$NOW.json
}

unseal() {
  export UNSEAL_TOKEN=$(cat /vault/data/vault_init_*.json | grep -o -A1 '"unseal_keys_b64"' |tail -n 1 | grep -o '"[^"]*' | grep -o '[^"]*$');
  vault operator unseal $UNSEAL_TOKEN
}

create_path() {
  export ROOT_TOKEN=$(cat /vault/data/vault_init_*.json | grep -o '"root_token": "[^"]*' | grep -o '[^"]*$');
  vault login $ROOT_TOKEN
  vault secrets enable -version=2 -path="secret" kv
  vault kv put secret/prd/portal/paas test=test
  vault kv put secret/prd/portal/maestro/url test=test
  vault kv put secret/prd/portal/maestro test=test
  vault kv put secret/data/prd/portal/maestro test=test
}

create_secret() {
  echo -e "ROOT_TOKEN=$ROOT_TOKEN\nUNSEAL_TOKEN=$UNSEAL_TOKEN\nSERVICE_VAULT_ROOT_TOKEN=$ROOT_TOKEN\nSPRING_CLOUD_VAULT_TOKEN=$ROOT_TOKEN" | tee /vault/data/secret.txt  
}

chown -R 100:1000 /vault/data

if [ -s /vault/data/secret.txt ]; then
  unseal
else
  init
  unseal
  create_path
  create_secret
#  insert_data
fi

inits=$(find . | grep vault_init)

for f in $inits
do
if [ ! -s $f ]; then
  rm -r $f
fi
done

vault status
