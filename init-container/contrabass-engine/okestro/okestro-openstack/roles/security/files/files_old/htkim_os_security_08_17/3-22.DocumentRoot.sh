apache_check=$(ps -ef | grep apache | grep -v grep)
file=/etc/apache2/sites-enabled/000-default.conf
documentcheck=$(cat $file | grep DocumentRoot | grep -Ev '^#' | awk '{print $2}')

if [[ "$apache_check" == "" ]];
then
     	echo -e "\033[0;32mApache Not use \033[0m"
else
	if [[ "$documentcheck" == "/var/www/html" ]] || [[ "$documentcheck" == "/usr/local/apache/htdocs" ]] || [[ "$documentcheck" == "/usr/local/apache2/htdocs" ]];
	then
	        echo -e "\033[0;32mDocumentRoot BAD!! \033[0m"
	        echo -e "DocumentRoot set $documentcheck Please change DocumentRoot" >> change_list.txt
	else
	        echo -e "\033[0;32mDocumentRoot GOOD!! \033[0m"
	fi
	
fi



