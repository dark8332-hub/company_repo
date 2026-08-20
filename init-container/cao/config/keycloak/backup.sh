#!/usr/bin/env sh

BACKUP_DATETIME=$(date +%Y%m%d-%H%M%S)
DIR=/var/lib/mysql


if [ ! -d $DIR/backup ]; then
  mkdir -p $DIR/backup
fi

mysqldump -u root -pokestro2018 --all-databases > $DIR/backup/mariadb_${BACKUP_DATETIME}.sql

if [ $? -eq 0 ]; then
  echo "Backup completed successfully"
else
  echo "Backup failed"
fi