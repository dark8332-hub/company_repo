check=$(cat /proc/sys/net/ipv4/icmp_echo_ignore_all)

if [[ "$check" -eq 0 ]];
then
        echo -e "\033[0;31mICMP Ignore BAD!! \033[0m"
	echo "change ICMP Ignore set change" >> change_list.txt
	echo 0 > /proc/sys/net/ipv4/icmp_echo_ignore_all
else
	echo -e "\033[0;32mICMP Ignore GOOD!! \033[0m"
fi
