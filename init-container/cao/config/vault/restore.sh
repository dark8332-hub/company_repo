#!/usr/bin/env sh                                                                                   
                                                                                                    
BACKUP_FILE=$1
DIR=/vault/data
                                                                                      
if [ $# != 1 ];then                                                                                 
  echo "ERROR: Usage: restore.sh <BACKUP_FILE>"                                                     
  exit 1                                                                                            
fi                                                                                                  
                                                                                                    
ROOT_TOKEN=$(cat $DIR/secret.txt | grep ^ROOT_TOKEN | cut -d'=' -f2-)                                    
UNSEAL_TOKEN=$(cat $DIR/secret.txt | grep ^UNSEAL_TOKEN | cut -d'=' -f2-)                                
                                                                                                    
vault login $ROOT_TOKEN                                                                             
                                                                                                    
vault operator raft snapshot restore -force $DIR/backup/$BACKUP_FILE                                            
vault operator unseal $UNSEAL_TOKEN