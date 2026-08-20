apache_check=$(ps -ef | grep apache | grep -v grep)
file=/etc/apache2/apache2.conf
#limit=$(cat $file | grep "ServerTokens Prod" | grep -Ev "^#|#ServerTokens Prod")
#limit_size=$(cat $file | grep "ServerTokens Prod" | awk '{print $2}')
count=$(cat $file | grep "<Directory" | grep -v '^#')

check=$(cat $file | sed -n "/<Directory/,/Directory>/p" | grep 'ServerTokens Prod')
Dirline=$(cat $file | grep "<Directory" | grep -vE '^#|</Directory' | sed "s/\/.*.//")
echo $Dirline

if [[ "$apache_check" == "" ]];
then
    	echo -e "\033[0;32mApache Not use \033[0m"
else
	if [[ "$check" == "" ]];
	then
	        echo -e "\033[0;31mServerTokens Not Found BAD!! \033[0m"
	        echo -e "ServerTokens Not Found BAD!!" >> change_list.txt
		echo "ServerTokens add all Directory in $file" >> change_list.txt
		sed -i'' -r -e "/^<Directory/a\	ServerTokens Prod" $file
		echo "Service apache2 restarting...."
		systemctl restart apache2
	else
	        echo -e "\033[0;32mServerTokens Exsit GOOD!! \033[0m"
	fi

	#echo $count
	#cat 123.txt | grep "Directory" | grep -vE '^#|</Directory' | sed 's/<//' | sed 's/>$//' | while read line
	#cat 123.txt | grep "<Directory" | grep -vE '^#|</Directory' | sed "s/\/.*.//" | while read line
	#cat 123.txt | sed -n "/<Directory/,/Directory>/p" | grep 'ServerTokens Prod' | while read line
	#do
	#	#echo $line | awk -F/ '{ for(i=1; i<=NF; i++) print $i}'
	#	echo $line #| awk -F/ '{ for(i=1; i<=NF; i++) print $i}'
	#	if [[ "$line" == "" ]];
	#	then
	#	        echo -e "\033[0;31mServerTokens Not Found BAD!! \033[0m"
	#		#sed -i'' -r -e "/$line/a\	ServerTokens Prod" $file
	#		#systemctl restart apache2
	#	else
	#	        echo -e "\033[0;32mServerTokens Exsit GOOD!! \033[0m"
	#	fi
	#done
	#for i in $count
	#do
		#if [[ "$limit" == "" ]];
		#then
		        #echo -e "\033[0;31mServerTokens Not Found BAD!! \033[0m"
			#sed -i'' -r -e "<Directory/a\	ServerTokens Prod" $file
			#systemctl restart apache2
		#else
		        #echo -e "\033[0;32mServerTokens Exsit GOOD!! \033[0m"
		#fi
	#done
fi
