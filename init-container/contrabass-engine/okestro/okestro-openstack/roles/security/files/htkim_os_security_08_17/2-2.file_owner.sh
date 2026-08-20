
echo "========== start nosuer ==========" >> ./un_change_list.txt
find / -nouser -print >>  ./change_list.txt
echo "========== end nosuer ==========" >> ./un_change_list.txt

echo "========== start group ==========" >> ./un_change_list.txt
find / -nogroup -print >> ./change_list.txt
echo "========== end group ==========" >> ./un_change_list.txt
