dns_check=$(ps -ef | grep "named -f -u bind" | grep -v grep)
dns_VersionCheck=$(dpkg -l | grep bind9 | awk '{print $3}' | awk -F- '{print $1}' | head -n1 | awk -F: '{print $2}')
dnsVersion_fault1=8.4.6
dnsVersion_fault2=8.4.7
dnsVersion_fault3=9.2.8-P1
dnsVersion_fault4=9.3.4-P1
dnsVersion_fault5=9.4.1-P1
dnsVersion_fault6=9.5.0a6


if [[ "$dns_check" == "" ]];
then
        echo -e "\033[0;32mDNS Service Not Use !! \033[0m"
else
	if [[ $dns_VersionCheck == "$dnsVersion_fault1" || $dns_VersionCheck == "$dnsVersion_fault2" || $dns_VersionCheck == "$dnsVersion_fault3" || $dns_VersionCheck == "$dnsVersion_fault4" || $dns_VersionCheck == "$dnsVersion_fault5" || $dns_VersionCheck == "$dnsVersion_fault6" ]];
	then
	        echo -e "\033[0;31mDNS Version $dns_VersionCheck BAD!! \033[0m"
	        echo "DNS Version $dns_VersionCheck Please Upgrade DNS Version" >> un_change_list.txt
	else
	        echo -e "\033[0;32mDNS Version $dns_VersionCheck GOOD!! \033[0m"
	fi
fi

