# Sqoop

## 一.sqoop搭建

### 1.安装环境

| 软件名称  | 版本                            |
| --------- | ------------------------------- |
| sqoop     | 1.4.6                           |
| mysql驱动 | mysql-connector-java-5.1.48.jar |

### 2.修改配置文件

* sqoop-env.sh

```
wget http://mirrors.hust.edu.cn/apache/sqoop/1.4.6/
cd /opt/module/sqoop/conf
vim sqoop-env.sh
	export HADOOP_COMMON_HOME=/opt/module/hadoop
	export HADOOP_MAPRED_HOME=/opt/module/hadoop
	export HIVE_HOME=/opt/module/hive
	export ZOOKEEPER_HOME=/opt/module/zookeeper
	export ZOOCFGDIR=/opt/module/zookeeper/conf
```

* copy 驱动 to lib

```
cp mysql-connector-java-5.1.48.jar /opt/module/sqoop/lib/
```

* 测试连接是否成功（root用户，mysql暂时没有授权给hadoop0的hadoop用户）

```
./bin/sqoop list-databases --connect jdbc:mysql://hadoop0:3306/ --username root --password 111111
```

## 二.同步策略

### 1.几种同步策略

```
全量表：存储完整的数据。适用于数据量不太大，每天既会有新数据插入，旧数据的修改
增量表：存储新增加的数据。适用于数据量大，每天只会有新数据插入
新增及变化表：存储新增加的数据和变化的数据，创建和操作都是今天的数据。适用于表数据量大，既有新增也有变化
特殊表：只需要存储一次。适用于(性别，地区and so on)
```



## 三.导入和导出

```
rdbms ==> Hdfs ==>hive,hbase
hdfs  ==>rdbms
hive,hbase ==>hdfs==>rdbms
```



### 1.from mysql to hdfs

```
#! /bin/bash
APP=gmall
sqoop=/opt/module/sqoop/bin/sqoop
# 如果是输入的日期按照取输入日期；如果没输入日期取当前时间的前一天
if [ -n "$2" ] ;then
   do_date=$2
else 
   //echo "Data is null"
   //exit
   do_date=`date -d '-1 day' +%F`	
fi 
import_data(){
$sqoop import \
--connect jdbc:mysql://hadoop102:3306/$APP \
--username root \
--password 123456 \
--target-dir /origin_data/$APP/db/$1/$do_date \
--delete-target-dir \
--query "$2 where \$CONDITIONS" \
--num-mappers 1 \
--fields-terminated-by '\t' \
--null-string '\\N' \
--null-non-string '\\N'
}
import_user_info(){
  import_data user_info "select
                            id, user_id, from user_info",create_time, operate_time,
                            where (date_format(create_time,'%Y-%m-%d')='$do_date' or date_format(operate_time,'%Y-%m-%d')='$do_date')"

}

case $1 in
  "order_info")
     import_user_info
;;
esac

```



### 3.hive & mysql about null

```
Hive中的Null在底层是以“\N”来存储，而MySQL中的Null在底层就是Null，为了保证数据两端的一致性。在
导出数据时采用--input-null-string和--input-null-non-string两个参数。
导入数据时采用--null-string和--null-non-string。
```

### 4.export

```
sqoop export \
  --connect jdbc:mysql://localhost:3306/retry_db \
  --username root \
  --password 111111 \
  --export-dir /testdatabase/departments \　　　　# HDFS source path for the export
  --table departments
```