#!/usr/bin/env sh

NOW=$(date +%Y%m%d-%H%M%S)
DIR=/vault/data

ROOT_TOKEN=$(cat $DIR/secret.txt | grep ^ROOT_TOKEN | cut -d'=' -f2-)
UNSEAL_TOKEN=$(cat $DIR/secret.txt | grep ^UNSEAL_TOKEN | cut -d'=' -f2-)

if [ ! -d $DIR/backup ]; then
  mkdir -p $DIR/backup
fi

vault login $ROOT_TOKEN
vault operator raft snapshot save $DIR/backup/backup_$NOW.snap

if [ $? -eq 0 ]; then
  echo "Backup completed successfully"
else
  echo "Backup failed"
fi
#sh /vault/data/backup.sh >> /vault/data/backup/error.log 2>&1 
