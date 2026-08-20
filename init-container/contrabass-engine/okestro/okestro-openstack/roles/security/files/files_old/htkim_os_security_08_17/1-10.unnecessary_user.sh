un_list=$(cat /etc/passwd | awk -F':' '{print $1}' | egrep "^(adm|lp|sync|shutdown|halt|news|uucp|operator|games|gopher|nfsnobody|squid)")



for i in $un_list
do
        sed -i "s/$i/#$i/g" /etc/passwd
	echo "$i add comment in /etc/passwd file" >> ./change_list.txt
done

