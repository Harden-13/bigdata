### Hive高级应用

#### 1.分区

##### 1.分区

* 分区实现的意义

```
分区表实际上就是对应一个HDFS文件系统上的独立的文件夹，该文件夹下是该分区所有的数据文件。Hive中的分区就是分目录，查询时通过where指定分区，提高效率
```

* 分区操作

```
//创建表 指定相应分区
create external table dept_partition_test(
deptno int, dname string, loc string
)
partitioned by (day string)
row format delimited fields terminated by '\t'
location '/user/hive/warehouse/test.db/dept_partition';
```

* 加载数据

```
//load指定hdfs，路径落实到文件名字上面
load data inpath '/user/hive/warehouse/test.db/dept_partition/day=20200401/dept_20200403.log' into table dept_partition_test partition(day='20200403');
```

* 查询分区

```
select * from dept_partition where day='20200401';
```

* 增加，删除，查看分区

```
//增加
alter table dept_partition add partition(day='20200404') ;
//删除
alter table dept_partition drop partition (day='20200404'), partition(day='20200405');
//查看
show partitions dept_partition;
```

##### 2.二级分区

* 创建

```
create table dept_partition2(
               deptno int, dname string, loc string
               )
               partitioned by (day string, hour string)
               row format delimited fields terminated by '\t';
```

* 数据加载

```
load data local inpath '/opt/module`/hive/datas/dept_20200401.log' into table
dept_partition2 partition(day='20200401', hour='12');
```

* 查询

```
select * from dept_partition2 where day='20200401' and hour='12';
```

##### 3.数据分区关联(数据修复)

* 上传数据后修复

```
//上传数据
dfs -put /opt/src/dept_20200401.log  /user/hive/warehouse/mydb.db/dept_partition2/day=20200401/hour=13;
//数据修复
msck repair table dept_partition2;
//查询
select * from dept_partition2 where day='20200401' and hour='13';
```

* 上传数据后添加分区

```
//上传数据
dfs -put /opt/src/dept_20200401.log  /user/hive/warehouse/mydb.db/dept_partition2/day=20200401/hour=13;
//添加分区
alter table dept_partition2 add partition(day='20200401',hour='13');
```

* 创建文件夹后load数据到分区

```
//创建目录
dfs -mkdir -p
 /user/hive/warehouse/mydb.db/dept_partition2/day=20200401/hour=15;
//上传数据
load data local inpath '/opt/module/hive/datas/dept_20200401.log' into table
 dept_partition2 partition(day='20200401',hour='15');

```

##### 4.动态分区

* 开启动态分区

```
hive.exec.dynamic.partition=true
//模式表示允许所有的分区字段都可以使用动态分区
hive.exec.dynamic.partition.mode=nonstrict
//在所有执行MR的节点上，最大一共可以创建多少个动态分区
hive.exec.max.dynamic.partitions=1000
//在每个执行MR的节点上，最大可以创建多少个动态分区,比如：源数据中包含了一年的数据，即day字段有365个值，那么该参数就需要设置成大于365，如果使用默认值100，则会报错。
hive.exec.max.dynamic.partitions.pernode=100
//整个MR Job中，最大可以创建多少个HDFS文件
hive.exec.max.created.files=100000
//当有空分区生成时，是否抛出异常
hive.error.on.empty.partition=false
```

* 需求将dept表中的数据按照地区（loc字段），插入到目标表dept_partition的相应分区中。\
* 分区表中partition(loc) select, loc from dept 一一对应，或者(partition(bj) select bj)

```sql
//（1）创建目标分区表
hive (default)> create table dept_partition_dy(id int, name string) partitioned by (loc int) row format delimited fields terminated by '\t';

//（2）设置动态分区
set hive.exec.dynamic.partition.mode = nonstrict;
hive (default)> insert into table dept_partition_dy partition(loc) select deptno, dname, loc from dept;
//（3）查看目标分区表的分区情况
hive (default)> show partitions dept_partition;
<!--思考：目标分区表是如何匹配到分区字段的-->

```



####  2.分桶

##### 1.分桶

* 分桶意义

```
分桶是将数据集分解成更容易管理的若干部分的另一个技术。
分区针对的是数据的存储路径；分桶针对的是数据文件。
```

* 创建分桶表

```
create table user_bucket(id int, name string)
clustered by(id) 
into 4 buckets
row format delimited fields terminated by '\t';

```

* 导入数据

```
 load data inpath '/user.txt' into table user_bucket;
```

* 结果

```
观察hdfs数据库的目录结构
select查看数据
```

* 分桶规则

```
Hive的分桶采用对分桶字段的值进行哈希，然后除以桶的个数求余的方 式决定该条记录存放在哪个桶当中
```

* 分桶注意事项

```
（1）reduce的个数设置为-1,让Job自行决定需要用多少个reduce或者将reduce的个数设置为大于等于分桶表的桶数
（2）从hdfs中load数据到分桶表中，避免本地文件找不到问题

```

