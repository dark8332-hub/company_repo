#!/bin/bash
DOCUMENTROOT1=$(cat /etc/apache2/sites-available/000-default.conf | grep -i DocumentRoot | sed 's/DocumentRoot//g' | sed 's/ //g' | sed 's/\t//g' | grep "/var/www/html" | wc -l)
DOCUMENTROOT2=$(cat /etc/apache2/sites-available/default-ssl.conf | grep -i DocumentRoot | sed 's/DocumentRoot//g' | sed 's/ //g' | sed 's/\t//g' | grep "/var/www/html" | wc -l)
LIMITREQUESTBODY=$(cat /etc/apache2/apache2.conf | grep -i LimitRequestBody | wc -l)
DIRNUM=$(cat /etc/apache2/apache2.conf | grep -i \^\<Directory | wc -l)
INDEXESFOLLOWSYMLINKS=$(cat /etc/apache2/apache2.conf | grep -i Options | sed 's/Options//g' | sed 's/ //g' | sed 's/\t//g' | grep "^IndexesFollowSymLinks" | wc -l)

#documentroot set
if [ $DOCUMENTROOT1 -eq 1 ] || [ $DOCUMENTROOT2 -eq 1 ]
then
  if [ ! -d /var/www/test ]
  then
    mkdir /var/www/test
    chmod 755 /var/www/test
  fi
fi

if [ $DOCUMENTROOT1 -eq 1 ]
then
  sed -i "s/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/test/g" /etc/apache2/sites-available/000-default.conf
fi

if [ $DOCUMENTROOT2 -eq 1 ]
then
  sed -i "s/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/test/g" /etc/apache2/sites-available/default-ssl.conf
fi

#limitrequestbody set
if [ $LIMITREQUESTBODY -ne $DIRNUM ]
then
  sed -i '/LimitRequestBody/d' /etc/apache2/apache2.conf
  sed -i'' -r -e '/^<Directory/a\\tLimitRequestBody 5000000' /etc/apache2/apache2.conf
fi

#indexfollowsymlinks set
if [ $INDEXESFOLLOWSYMLINKS -ge 1 ]
then
  sed -i "s/Options Indexes FollowSymLinks/Options None/g" /etc/apache2/apache2.conf
fi

systemctl restart apache2
