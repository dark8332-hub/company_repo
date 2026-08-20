#!/usr/bin/env sh

DIR=/vault/data                                                                                      
                                                                                                
SEALED=$(vault status | grep -i "SEALED." | awk '{print $2}');

if [ "$SEALED" = "true" ];then
    ROOT_TOKEN=$(cat $DIR/secret.txt | grep ^ROOT_TOKEN | cut -d'=' -f2-)                                    
    UNSEAL_TOKEN=$(cat $DIR/secret.txt | grep ^UNSEAL_TOKEN | cut -d'=' -f2-)

    vault login $ROOT_TOKEN                                                                                                                                                                                 
    vault operator unseal $UNSEAL_TOKEN
fi
