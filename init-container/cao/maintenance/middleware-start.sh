nerdctl compose -f ../chmod.yaml up -d
nerdctl compose -f ../middleware-compose.yaml up -d
nerdctl compose -f ../vault-init.yaml up -d

sleep 15

nerdctl cp vault:/vault/data/secret.txt ../config/vault/secret.env
sudo chmod 775 ../config/vault/secret.env
echo "VAULT_TOKEN=$(grep '^SERVICE_VAULT_ROOT_TOKEN=' ../config/vault/secret.env | cut -d '=' -f2)" >> ../config/vault/secret.env
echo "BATON_VAULT_TOKEN=$(grep '^SERVICE_VAULT_ROOT_TOKEN=' ../config/vault/secret.env | cut -d '=' -f2)" >> ../config/vault/secret.env
echo "VAULT_ROOT_TOKEN=$(grep '^SERVICE_VAULT_ROOT_TOKEN=' ../config/vault/secret.env | cut -d '=' -f2)" >> ../config/vault/secret.env

exit 0

