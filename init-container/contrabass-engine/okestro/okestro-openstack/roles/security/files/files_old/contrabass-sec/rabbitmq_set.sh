#!/bin/bash
USERS=$(rabbitmqctl list_users | grep -i guest | wc -l)
FILE=$(ls ./ | grep -i rabbitmq_other_authority.txt | wc -l )
HOSTNAME=$(hostname -f)

#delete guest user
if [ $USERS -ne 0 ]
then
  rabbitmqctl delete_user guest
fi

#others authority set
chmod -R o-w /var/lib/rabbitmq/mnesia

if [ $FILE -eq 0 ]
then
  touch rabbitmq_other_authority.txt
fi

RESULT=$(ls -al /var/lib/rabbitmq/mnesia/rabbit@$HOSTNAME)
cat /dev/null > rabbitmq_other_authority.txt
echo -e "$RESULT" >> rabbitmq_other_authority.txt

systemctl restart rabbitmq-server.service
