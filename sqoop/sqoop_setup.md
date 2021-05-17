# Sqoop

## 1.sqoop搭建

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

