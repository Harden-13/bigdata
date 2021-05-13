#!/bin/bash

if [ $# -lt 1 ]
then
	echo "缺少参数"
	exit
fi

for host in hadoop1 hadoop2
do
    for file in $@
    do
		if [ -e $file  ]
		then
			path=$(cd -P `dirname $file`;pwd)
			filename=`basename $file`
			ssh $host "mkdir -p $path"
			rsync -av $path/$filename $host:$path
		else
			echo "$file 不存在"
			exit
		fi
    done
done  
