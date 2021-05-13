#!/bin/bash

if [ $# -lt 1 ]
then
	echo "参数不全"
	exit
fi


for host in hadoop0 hadoop1 hadoop2
do
	for command in "$*"
	do
		echo "#########执行$host#########$command"
		ssh $host $command
	done
done
