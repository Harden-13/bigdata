## <span style='color:red'>hbase</span>

### <span style='color:yellow'>hbase介绍</span>

#### 1.逻辑结构

* 图片介绍

![hbase结构](C:\Users\lenovo\Desktop\bigdata\hbase\hbase结构.png)



![hbase](C:\Users\lenovo\Desktop\bigdata\hbase\hbase.png)

#### 2.存储结构

* 图片介绍

![hbase存储结构](C:\Users\lenovo\Desktop\bigdata\hbase\hbase存储结构.png)

#### 3.数据结构

* 数据模型

| Hbase          |                                                              |
| -------------- | ------------------------------------------------------------ |
| **namespace**  | 库；HBase有两个自带的命名空间，**hbase**中存放的是HBase内置的表，**default**表是用户默认使用的命名空间。 |
| **table**      | 表                                                           |
| **row**        | 行数据；每行数据都由一个**RowKey**和多个**Column**（列）组成 |
| **colume**     | 列数据；**Column Family**(列族)和**Column Qualifier**（列限定符）进行限定 |
| **time stamp** | 标识数据的不同版本**（version）**，每条数据写入时，系统会自动为其加上该字段，其值为写入HBase的时间 |
| **cell**       | {rowkey, column Family：column Qualifier, time Stamp} 唯一确定的单元。cell中的数据全部是字节码形式存贮。 |

#### 4.基本架构

* 架构角色

| 角色              | 功能                      | 实现类        | 表操作                | 作用                                                         |
| ----------------- | ------------------------- | ------------- | --------------------- | ------------------------------------------------------------ |
| **master**        | 所有Region Server的管理者 | HMaster       | create, delete, alter | 分配regions到每个RegionServer，监控每个RegionServer的状态，负载均衡和故障转移。 |
| **region server** | Region的管理者            | HRegionServer | get, put, delete；    | 对region操作splitRegion、compactRegion                       |
| **zookeeper**     | 实现master的高可用        |               |                       | 对RegionServer的监控、元数据的入口以及集群配置的维护等工作   |
| **hdfs**          | 提供底层数据存储服务      |               |                       | 为HBase提供数据高可用的支持                                  |

### ha-hbase搭建

#### 1.环境准备

* 软件版本

| 软件          | 版本  |
| ------------- | ----- |
| **zookeeper** | 3.5.7 |
| **hadoop**    | 3.1.3 |
| **hbase**     | 2.0.5 |

#### 2.依赖服务

* 保证zookeeper正常启动
* 保证hadoop正常启动

##### 1.安装hbase

* 解压包&配置环境变量

```
tar -xvf hbase-2.0.5-bin.tar.gz -C /opt/module/
ln -s hbase-2.0.5 hbase
vim /etc/profile.d/hadoop.sh
	#HBASE_HOME
	export HBASE_HOME=/opt/module/hbase
	export PATH=$PATH:$HBASE_HOME/bin
```

* hbase-env.sh修改内容：

```
export HBASE_MANAGES_ZK=false
```

* hbase-site.xml修改内容

```
    <property>
        <name>hbase.rootdir</name>
        <value>hdfs://mycluster:8020/hbase</value>
    </property>

    <property>
        <name>hbase.cluster.distributed</name>
        <value>true</value>
    </property>

    <property>
        <name>hbase.zookeeper.quorum</name>
        <value>hadoop0,hadoop1,hadoop2</value>
    </property>

```

* regionservers

```
hadoop0
hadoop1
hadoop2
```

* conf/backup-masters

```
hadoop1
```

* hbase目录，环境变量分发到hadoop1,hadoop2

```
my_rsync.sh hbase-2.0.5
my_rsync.sh /etc/profile.d/hadoop.sh
```

* 启动

```
start-hbase.sh
```

##### 2.查看页面

* master

```
http://hadoop0:16010 
```

* backup

```
http://hadoop1:16010 
```

##### 3.关于时间同步

* 如果集群之间的节点时间不同步，会导致regionserver无法启动，抛出ClockOutOfSyncException异常。

* 属性：hbase.master.maxclockskew设置更大的值

```
<property>
        <name>hbase.master.maxclockskew</name>
        <value>180000</value>
        <description>Time difference of regionserver from master</description>
</property>

```

#### 3.常用命令

* 命令（http://ascii.911cha.com/）

```
# 创建命名空间
create 'student','info'
# 加数据
put 'student','1001','info:sex','male'
put 'student','1001','info:age','18'
# 查看
scan 'student',{STARTROW => '1001!', STOPROW  => '1001|'} //|或者！ascii无限大或者小接近，
# 更新
put 'student','1001','info:name','Nick'
# 查看
get 'student','1001','info:name'
# 更改版本
alter 'student',{NAME=>'info',VERSIONS=>3}
# 删除先disable
disable 'student'；drop 'student'
```

* 补充命令

```
list
list_namespace_tables
describe
scan 'table_name',{RAW=>true,VERSIONS=>5}
```

* 删除标记

```
delete
deleteColum
deleteFamily
```

