### HIVE SQL

#### 1.DDL语句

##### 1.创建数据库

```
CREATE DATABASE [IF NOT EXISTS] database_name
[COMMENT database_comment]
[LOCATION hdfs_path]
[WITH DBPROPERTIES (property_name=property_value, ...)];
```

* [LOCATION hdfs_path]

```
数据库在HDFS上的默认存储路径是/user/hive/warehouse/*.db。
//指定放在hdfs根目录
create database db_hive2 location '/db_hive2.db';
```

##### 2.删除数据库

```
drop database dbname;
```

* 强制删除不为空的数据库

```
drop database dbname cascade;
```

##### 3.创建表

* 常用创建表的字段

```
CREATE [EXTERNAL] TABLE [IF NOT EXISTS] table_name 
[(col_name data_type [COMMENT col_comment], ...)] 
[COMMENT table_comment] 
[PARTITIONED BY (col_name data_type [COMMENT col_comment], ...)] 
[CLUSTERED BY (col_name, col_name, ...) 
[SORTED BY (col_name [ASC|DESC], ...)] INTO num_buckets BUCKETS] 
[ROW FORMAT row_format] 
[STORED AS file_format] 
[LOCATION hdfs_path]
[TBLPROPERTIES (property_name=property_value, ...)]
[AS select_statement]


```

* 字段解释说明

```
（1）CREATE TABLE 创建一个指定名字的表。如果相同名字的表已经存在，则抛出异常；用户可以用 IF NOT EXISTS 选项来忽略这个异常。
（2）EXTERNAL关键字可以让用户创建一个外部表，在建表的同时可以指定一个指向实际数据的路径（LOCATION），在删除表的时候，内部表的元数据和数据会被一起删除，而外部表只删除元数据，不删除数据。
（3）COMMENT：为表和列添加注释。
（4）PARTITIONED BY创建分区表
（5）CLUSTERED BY创建分桶表
（6）SORTED BY不常用，对桶中的一个或多个列另外排序
（7）ROW FORMAT 
DELIMITED [FIELDS TERMINATED BY char] [COLLECTION ITEMS TERMINATED BY char]
        [MAP KEYS TERMINATED BY char] [LINES TERMINATED BY char] 
   | SERDE serde_name [WITH SERDEPROPERTIES (property_name=property_value, property_name=property_value, ...)]
用户在建表的时候可以自定义SerDe或者使用自带的SerDe。如果没有指定ROW FORMAT 或者ROW FORMAT DELIMITED，将会使用自带的SerDe。在建表的时候，用户还需要为表指定列，用户在指定表的列的同时也会指定自定义的SerDe，Hive通过SerDe确定表的具体的列的数据。
SerDe是Serialize/Deserilize的简称， hive使用Serde进行行对象的序列与反序列化。
（8）STORED AS指定存储文件类型
常用的存储文件类型：SEQUENCEFILE（二进制序列文件）、TEXTFILE（文本）、RCFILE（列式存储格式文件）
如果文件数据是纯文本，可以使用STORED AS TEXTFILE。如果数据需要压缩，使用 STORED AS SEQUENCEFILE。
（9）LOCATION ：指定表在HDFS上的存储位置。
（10）AS：后跟查询语句，根据查询结果创建表。
（11）LIKE允许用户复制现有的表结构，但是不复制数据。

```

###### a.内部表

* 内部表理论

```
当我们删除一个管理表时，Hive也会删除这个表中数据。管理表不适合和其他工具共享数据。
```

###### b.外部表

* 外部表场景
* drop EXTERNAL table (hive中表没了，但是数据还在hdfs上)

```
每天将收集到的网站日志定期流入HDFS文本文件。在外部表（原始日志表）的基础上做大量的统计分析，用到的中间表、结果表使用内部表存储，数据通过SELECT+INSERT进入内部表。
```

```sql
前提：
	1.创建外部表ods_log
	2.从/origin_data/gmall/log/topic_log/2020-06-14'导入数据到ods_log，hdfs把原数据移动到ods_log
	3.删除外部表ods_log，表没有了数据在/warehouse/gmall_test/ods/ods_log目录中
	4.重新创建外部表ods_log和导入数据的 sql参照下图

create external table  if not exists ods_log (aa string)
 partitioned by (dt string)
 LOCATION '/warehouse/gmall_test/ods/ods_log'; -- 指定数据在hdfs上的存储位置
// 
load data inpath '/warehouse/gmall_test/ods/ods_log/' into table ods_log
    partition(dt='2020-06-14') ;
```



###### c.内部表外部表相互转换

```
//转换成外部表
alter table tablename set tblproperties('EXTERNAL'='TRUE');
```

###### d.删除表

```
drop table tablename
```



#### 2.DML数据操作

##### 1.导入的几种方式

###### 1.load数据导入(不常用)

```
load data [local] inpath '数据的path' [overwrite] into table student [partition (partcol1=val1,…)];
（1）load data:表示加载数据
（2）local:表示从本地加载数据到hive表；否则从HDFS加载数据到hive表
（3）inpath:表示加载数据的路径
（4）overwrite:表示覆盖表中已有数据，否则表示追加
（5）into table:表示加载到哪张表
（6）student:表示具体的表
（7）partition:表示上传到指定分区

```

###### 2.insert数据导入(常用)

```
//new_tablename.desc = old_tablename.desc前提，保证字段一致
insert overwrite table new_tablename select * from old_tablename ;
备注：
insert into：以追加数据的方式插入到表或分区，原有数据不会删除
insert overwrite：会覆盖表中已存在的数据
```

###### 3.as select创建并加载数据导入

```
create table if not exists new_table
as select * from old_table;
```

###### 4.location指定数据路径导入

```
//模拟数据在指定路径
hadoop fs -put hivetesttable.txt  hdfs://hadoop2:8020/user/hive/warehouse/hivetest.db/hivetesttable/
//创建相应表指定路径
create external table if not exists tablename(
              id int, name string
              )
              row format delimited fields terminated by '\t'
              location '/user/hive/warehouse/hivetest.db/hivetesttable;

```

###### 5.Import数据到指定Hive表中

```
//先用export导出后，再将数据导入
import table tablename  from
 '/user/hive/warehouse/export/student';
```

##### 2.导出几种方式

###### 1.insert导出

* 导出本地

```
insert overwrite local directory '/opt/src/table_name'
select * from tablename
//报错
Error, return code 1 from org.apache.hadoop.hive.ql.exec.MoveTask
//解决
hadoop用户可以操作本地目录
```

* 格式化导出

```
insert overwrite local directory '/opt/src/table_name'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
select * from tablename
```

* 导出hdfs

```
insert overwrite directory '/...../table_name'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' 
select * from tablename;
```

###### 2.hadoop导出到本地（不常用）

```
dfs -get /user/hive/warehouse/student/student.txt
/opt/src/datas/export/student3.txt;

```

###### 3.hive导出

```
hive -e 'select * from default.student;' >
 /opt/src/datas/export/student4.txt;

```

###### 4.export导出到hdfs

```
//export和import主要用于两个Hadoop平台集群之间Hive表迁移
export table tablename to
 '/user/hive/warehouse/export/student';
```

##### 3.清空表中数据

```
//只能删除内部表，不能删除外部表
truncate table student;
```

##### **4.查询**

* 查询语法

```
SELECT [ALL | DISTINCT] [as] [alias]  select_expr, select_expr, ...
  FROM table_reference
  [WHERE where_condition]
  [GROUP BY col_list]
  [ORDER BY col_list]
  [CLUSTER BY col_list
    | [DISTRIBUTE BY col_list] [SORT BY col_list]
  ]
 [LIMIT number]
//DISTINCT，返回唯一不同的值

```

* like

```
选择条件可以包含字符或数字:
% 代表零个或多个字符(任意个字符)。
_ 代表一个字符。
```

* group by

```
GROUP BY语句通常会和聚合函数一起使用，按照一个或者多个列队结果进行分组，然后对每个组执行聚合操作
```

* having

```
（1）where后面不能写分组函数，而having后面可以使用分组函数。 //avg sum count
（2）having只用于group by分组统计语句。
```

###### 1. join

* inner join

```
select
d.deptno,e.empno, e.ename
from
dept d
left outer join
emp e
on
e.deptno=d.deptno;
```

* left outer join

```
select
d.deptno,e.empno, e.ename
from
dept d
left outer join
emp e
on
e.deptno=d.deptno;
```

* dept表独有得（B表独有，右连接，where条件换一下）

```
select
d.deptno,e.empno, e.ename
from
dept d
left join
emp e
on
e.deptno=d.deptno
where e.deptno is null;
```

* FULL(将会返回所有表中符合WHERE语句条件的所有记录)
* 主表独有的+从表独有的+主从inner join的  
* <mark>~~主从inner join的  + 从表独有的 （因为id=id，有id依赖所以不可能出现主表独有）~~</mark>

```
select
d.deptno,e.empno, e.ename
from
dept d
full join
emp e
on
e.deptno=d.deptno;
```

###### 2.排序

* order by全局排序

```
Order By：全局排序，只有一个Reducer
ASC（ascend）: 升序（默认）
DESC（descend）: 降序
ORDER BY 子句在SELECT语句的结尾
ORDER BY COLUM1,COLUM2 多个列排序
```

* sort by内部排序reduce

```
Sort By：对于大规模的数据集order by的效率非常低。在很多情况下，并不需要全局排序，此时可以使用sort by。
Sort by为每个reducer产生一个排序文件。每个Reducer内部进行排序，对全局结果集来说不是排序
```

```
set mapreduce.job.reduces=3; //设置reduce个数

insert overwrite local directory '/opt/src/sortby-result'
row format delimited fields terminated by '\t'
select sal,ename,deptno from emp sort by sal desc;  //将查询结构导入到文件
```

* Distribute By分区

```
Distribute By： 需要控制某个特定行应该到哪个reducer，通常是为了进行后续的聚集操作。distribute by 子句可以做这件事。distribute by类似MR中partition（自定义分区），进行分区，结合sort by使用。 一定要分配多reduce进行处理
```

```
set mapreduce.job.reduces=3; //设置reduce个数
//分区规则，分区字段%reduces的个数，余数相同进到一组
insert overwrite local directory '/opt/src/sortby-result'
row format delimited fields terminated by '\t' select deptno,empno,sal from emp distribute by deptno sort by empno desc
```

* Cluster By

```
当distribute by和sort by字段相同时，可以使用cluster by方式。
cluster by除了具有distribute by的功能外还兼具sort by的功能。但是排序只能是升序排序
```

###### 3. UNION 

* syntax

```sql
select_statement UNION [ALL | DISTINCT] select_statement UNION [ALL | DISTINCT] select_statement ...

用来合并多个select的查询结果，需要保证select中字段须一致，每个select语句返回的列的数量和名字必须一样，否则，一个语法错误会被抛出。
```

* 可选关键字

```
使用DISTINCT关键字与使用UNION 默认值效果一样，都会删除重复行
使用ALL关键字，不会删除重复行，结果集包括所有SELECT语句的匹配行（包括重复行）

Hive 1.2.0和更高版本中，UNION的默认行为是从结果中删除重复的行。
```

* hive的一个特点

```
hive的Union All相对sql有所不同,要求列的数量相同,并且对应的列名也相同,但不要求类的类型相同(可能是存在隐式转换吧)
```



###### 4. with子查询

* with as是hive中独有 一次分析，多次使用，
* 使用注意事项

```
1. with子句必须在引用的select语句之前定义,同级with关键字只能使用一次,多个只能用逗号分割；最后一个with 子句与下面的查询之间不能有逗号，只通过右括号分割,with 子句的查询必须用括号括起来.

2.如果定义了with子句，但其后没有跟select查询，则会报错！

3.前面的with子句定义的查询在后面的with子句中可以使用。但是一个with子句内部不能嵌套with子句！
```

* 使用

```sql
WITH t1 AS (
		SELECT *
		FROM carinfo
	), 
	t2 AS (
		SELECT *
		FROM car_blacklist
	)
SELECT *
FROM t1, t2
```



### 显示信息

##### 1.显示数据库

* 显示数据库信息

```
 desc database dbname;
```

* 显示数据库详细信息

```
desc database extended dbname;
```

##### 2.显示表信息

* 查看表格式化信息

```
desc formatted tablename;
```



