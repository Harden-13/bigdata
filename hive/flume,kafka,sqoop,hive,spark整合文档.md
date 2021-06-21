# flume,kafka,sqoop,hive,spark整合文档



## sqoop

首日同步脚本

mysql_to_hdfs_init.sh

把所有的数据查询出来---->hdfs:///origin_data/$APP/db/$1/$do_date--->按照时间目录



mysql_to_hdfs.sh

每日查询出来数据 ------>当天的时间目录