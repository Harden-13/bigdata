# **Phoenix**

## **一**.phoenix特点

```
1）容易集成：如Spark，Hive，Pig，Flume和Map Reduce；
2）操作简单：DML命令以及通过DDL命令创建和操作表和版本化增量更改；
3）支持HBase二级索引创建。
```

## 二.phoenix搭建

### 1.版本介绍

| 软件    | 版本                           |
| ------- | ------------------------------ |
| phoenin | apache-phoenix-5.0.0-HBase-2.0 |
|         |                                |

### 2.依赖服务

* 保证zk启动
* hadoop ha 启动
* hbase ha 启动

### 3.搭建步骤(hadoop用户搭建)

```
tar -xvf apache-phoenix-5.0.0-HBase-2.0-bin.tar.gz -C /opt/module/
ln -s apache-phoenix-5.0.0-HBase-2.0-bin phoenix
cp /opt/module/phoenix/phoenix-5.0.0-HBase-2.0-server.jar /opt/module/hbase/lib/
# 分发到3台机器hadoop0,hadoop1.hadoop2
my_rsync.sh /opt/module/hbase/lib/phoenix-5.0.0-HBase-2.0-server.jar
# 配置环境变量
vim /etc/profile.d/hadoop.sh
	#phoenix-env
    export PHOENIX_HOME=/opt/module/phoenix
    export PHOENIX_CLASSPATH=$PHOENIX_HOME
    export PATH=$PATH:$PHOENIX_HOME/bin
# 重启hbase
stop-hbase.sh
# 连接
/opt/module/phoenix/bin/sqlline.py 
```

## 三.phoenix shell

#### 1.schema操作

##### 1.schema创建

* 修改配置文件<span style='color:red'>**hbase-site.xml**</span>

```
   <property>
        <name>phoenix.schema.isNamespaceMappingEnabled</name>
        <value>true</value>
    </property>

```

