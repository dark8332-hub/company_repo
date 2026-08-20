file=/etc/exports
passwd_permission=$(ls -la $file | awk '{print $1}' | cut -c2-10)
passwd_permission_owner=$(ls -la $file | awk '{print $1}' | cut -c2-4)
passwd_permission_group=$(ls -la $file | awk '{print $1}' | cut -c5-7)
passwd_permission_other=$(ls -la $file | awk '{print $1}' | cut -c8-10)
owner=0
group=0
other=0


if [[ "$passwd_permission_owner" == *"r"* ]];
then
	let owner=$owner+4
fi
if [[ "$passwd_permission_owner" == *"w"* ]];
then
	let owner=$owner+2
fi
if [[ "$passwd_permission_owner" == *"x"* ]];
then
	let owner=$owner+1
fi



if [[ "$passwd_permission_group" == *"r"* ]];
then
	let group=$group+4
fi
if [[ "$passwd_permission_group" == *"w"* ]];
then
	let group=$group+2
fi
if [[ "$passwd_permission_group" == *"x"* ]];
then
	let group=$group+1
fi



if [[ "$passwd_permission_other" == *"r"* ]];
then
	let other=$other+4
fi
if [[ "$passwd_permission_other" == *"w"* ]];
then
	let other=$other+2
fi
if [[ "$passwd_permission_other" == *"x"* ]];
then
	let other=$other+1
fi

let permission=$(echo  $owner$group$other)
echo $permission

if [[ "$permission" -le "644" ]];
then
        echo -e "\033[0;32mPermit GOOD!! \033[0m"
else
	chmod 644 $file
        echo -e "\033[0;31m$file Permission change \033[0m"
	echo "$file Permission change" >> ./change_list.txt
fi

chown=$(ls -la $file | awk '{print $3}')
echo $chown

if [[ "$chown" == "root" ]];
then
        echo -e "\033[0;32mCHOWN GOOD!! \033[0m"
else
        echo -e "\033[0;31m$file owner change \033[0m"
	chown root $file
	echo "$file OWNER change to root" >> ./change_list.txt
fi

