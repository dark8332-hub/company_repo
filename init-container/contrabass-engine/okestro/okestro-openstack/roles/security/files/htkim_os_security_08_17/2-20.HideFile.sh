hide_file=$(find / -name '.*')


echo "Hide File List:" >> change_list.txt
for i in $hide_file
do
	echo $i >> un_change_list.txt
done
