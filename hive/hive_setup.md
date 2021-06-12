### HIVE

* hive 功能结构

```
1.把数据生成表格由hive metastore服务提供
2.sql转换mapreduce由hive hiveserver2服务提供
```



#### 1.hive预先安装环境

```
1.mysql5.7(存储hive元数据)
2.hive3.1.2
3.mysql驱动
4.启动用户，保持和hadoop集群一致
```

#### 2.mysql安装

* mysql安装

```
1.yum安装mysql5.7，安装步骤略
```

* 授权远程访问

```
mysql> update mysql.user set host='%' where user='root';
mysql> flush privileges;
```

* 创建hive源数据库

```
create database metastore;
```

#### 3.Hive安装

* 环境变量设置

```
#HIVE_HOME
HIVE_HOME=/opt/module/hive
PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin
export PATH JAVA_HOME HADOOP_HOME HIVE_HOME

```

##### 1. Hive元数据配置到MySql

```
cp /opt/software/mysql-connector-java-5.1.48.jar $HIVE_HOME/lib
```

##### 2.  配置Metastore到MySql

* ../conf/hive-site.xml

```
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <!-- jdbc连接的URL -->
    <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:mysql://hadoop0:3306/metastore?useSSL=false</value>
	</property>

    <!-- jdbc连接的Driver-->
    <property>
        <name>javax.jdo.option.ConnectionDriverName</name>
        <value>com.mysql.jdbc.Driver</value>
	</property>

	<!-- jdbc连接的username-->
    <property>
        <name>javax.jdo.option.ConnectionUserName</name>
        <value>root</value>
    </property>

    <!-- jdbc连接的password -->
    <property>
        <name>javax.jdo.option.ConnectionPassword</name>
        <value>111111</value>
	</property>

    <!-- Hive默认在HDFS的工作目录 -->
    <property>
        <name>hive.metastore.warehouse.dir</name>
        <value>/user/hive/warehouse</value>
    </property>
    
   <!-- Hive元数据存储的验证 -->
    <property>
        <name>hive.metastore.schema.verification</name>
        <value>false</value>
    </property>
   
    <!-- 元数据存储授权  -->
    <property>
        <name>hive.metastore.event.db.notification.api.auth</name>
        <value>false</value>
    </property>
    <!--打印表头-->
    <property>
    	<name>hive.cli.print.header</name>
    	<value>true</value>
  </property>
   <property>
    	<name>hive.cli.print.current.db</name>
    	<value>true</value>
  </property>
</configuration>

```

##### 3.初始化元数据

```
schematool -initSchema -dbType mysql -verbose
```

##### 4.启动hive

* first，启动hadoop集群

```
参考hadoop集群命令启动
```

* 启动hive

```
hive
```

#### 4.hive访问方式

##### 1.metastore方式访问

* **hive-site.xml**配置

```
    <!-- 指定存储元数据要连接的地址 -->
    <property>
        <name>hive.metastore.uris</name>
        <value>thrift://hadoop102:9083</value>
    </property>

```

* 启动metastore & 启动hive

```
nohup hive --service metastore 2>&1 &
hive
```

##### 2.jdbc方式访问

* **hive-site.xml**配置

```
    <!-- 指定hiveserver2连接的host -->
    <property>
        <name>hive.server2.thrift.bind.host</name>
        <value>hadoop0</value>
    </property>

    <!-- 指定hiveserver2连接的端口号 -->
    <property>
        <name>hive.server2.thrift.port</name>
        <value>10000</value>
    </property>

```

* 启动hiveserver2

```
nohup hive --service hiveserver2 >/opt/module/hive/logs/hiveserver2.log 2>&1 &
```

* 启动beeline客户端

```
beeline -u jdbc:hive2://hadoop0:10000 -n hadoop
```

#### 5.日志路径

##### 1.默认log日志 

```
Hive的log默认存放在/tmp/hadoop/hive.log目录下（当前用户名下）
```

##### 2.更改hive的日志路径

* hive-log4j2.properties(mv .template)

```
property.hive.log.dir=/opt/module/hive/logs
```

#### 6 参数配置

##### 1.查看配置

```
hive>set;
hive>set mapred.reduce.tasks;
```

##### 2.配置参数

* 配置文件

```
默认配置文件：hive-default.xml 
用户自定义配置文件：hive-site.xml
注意：用户自定义配置会覆盖默认配置。另外，Hive也会读入Hadoop的配置，因为Hive是作为Hadoop的客户端启动的，Hive的配置会覆盖Hadoop的配置。配置文件的设定对本机启动的所有Hive进程都有效。
```

* 命令行参数方式(临时生效)

```
 bin/hive -hiveconf mapred.reduce.tasks=10;
```

* 参数声明方式

```
hive (default)> set mapred.reduce.tasks=100;
```

* 配置方式优先级

```
上述三种设定方式的优先级依次递增。即配置文件<命令行参数<参数声明
```

#### 7 hive数据类型

##### 1.基本数据类型

| Hive数据类型 | Java数据类型 | 长度                                                         | 例子                                   |
| ------------ | ------------ | ------------------------------------------------------------ | -------------------------------------- |
| TINYINT      | byte         | 1byte有符号整数                                              | 20                                     |
| SMALINT      | short        | 2byte有符号整数                                              | 20                                     |
| INT          | int          | 4byte有符号整数                                              | 20                                     |
| BIGINT       | long         | 8byte有符号整数                                              | 20                                     |
| BOOLEAN      | boolean      | 布尔类型，true或者false                                      | TRUE  FALSE                            |
| FLOAT        | float        | 单精度浮点数                                                 | 3.14159                                |
| DOUBLE       | double       | 双精度浮点数                                                 | 3.14159                                |
| STRING       | string       | 字符系列。可以指定字符集。可以使用单引号或者双引号。   Hive的String类型相当于数据库的varchar类型，该类型是一个可变的字符串，不过它不能声明其中最多能存储多少个字符，理论上它可以存储2GB的字符数。 | ‘now is the time’   “for all good men” |
| TIMESTAMP    |              | 时间类型                                                     |                                        |
| BINARY       |              | 字节数组                                                     |                                        |

##### 2.集合数据类型

| 数据类型 | 描述                                                         | 语法示例                                          |
| -------- | ------------------------------------------------------------ | ------------------------------------------------- |
| STRUCT   | 和c语言中的struct类似，都可以通过“点”符号访问元素内容。例如，如果某个列的数据类型是STRUCT{first STRING, last   STRING},那么第1个元素可以通过字段.first来引用。 | struct()   例如struct<street:string, city:string> |
| MAP      | MAP是一组键-值对元组集合，使用数组表示法可以访问数据。例如，如果某个列的数据类型是MAP，其中键->值对是’first’->’John’和’last’->’Doe’，那么可以通过字段名[‘last’]获取最后一个元素 | map()   例如map<string, int>                      |
| ARRAY    | 数组是一组具有相同类型和名称的变量的集合。这些变量称为数组的元素，每个数组元素都有一个编号，编号从零开始。例如，数组值为[‘John’, ‘Doe’]，那么第2个元素可以通过数组名[1]进行引用。 | Array()   例如array<string>                       |

##### 3 练习

* json数据格式

```
{
    "name": "jhrden",
    "friends": ["curry" , "paul"] ,       //列表Array, 
    "children": {                      //键值Map,
        "james": 19 ,
        "harden": 18
    }
    "address": {                      //结构Struct,
        "street": "xxxx" ,
        "city": "usa" 
    }
}

```

* 创建本地数据

```
jhadrden,curry_paul,ddd:18_xiaoxiao song:19,xxxxxx_usa
lbj,wade_melo,ccc:18_xiaoxiao yang:19,bbbbb_usa
注意：MAP，STRUCT和ARRAY里的元素间关系都可以用同一个字符表示，这里用“_”
```

* 创建表和库

```
create database hive_test;
create table datatype(
name string,
friends array<string>,
children map<string, int>,
address struct<street:string, city:string>
)
row format delimited fields terminated by ','
collection items terminated by '_'
map keys terminated by ':'
lines terminated by '\n';

```

```
字段解释：
row format delimited fields terminated by ','  -- 列分隔符
collection items terminated by '_'  	--MAP STRUCT 和 ARRAY 的分隔符(数据分割符号)
map keys terminated by ':'			-- MAP中的key与value的分隔符
lines terminated by '\n';				-- 行分隔符

```

* hive导入数据到hdfs并查询

```
load data local inpath '/opt/src/hive_test.txt' into table datatype;
```

```
select name, friends[0],children["ccc"],address.street from datatype;
```

#### 8.idea连接hive

* idea maven依赖目录$USER\.m2\repository\org\apache\hive\hive-common\3.1.2\hive-common-3.1.2.jar

```
idea 2019.2.3 
reference ：https://zhuangyea.github.io/2019/05/06/idea/%E4%BD%BF%E7%94%A8IDEA%20Database%20Tool%E8%BF%9E%E6%8E%A5Hive%E6%95%B0%E6%8D%AE%E5%BA%93/
```

