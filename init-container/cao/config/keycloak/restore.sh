#!/usr/bin/env sh                                                                                   
                                                                                                    
BACKUP_FILE=$1
DIR=/var/lib/mysql
                                                                                      
if [ $# != 1 ];then                                                                                 
  echo "ERROR: Usage: restore.sh <BACKUP_FILE>"                                                     
  exit 1                                                                                            
fi                                                                                                  
                                                                                                                                   
mysql -u root -p okestro2018 < $DIR/backup/${BACKUP_FILE}
