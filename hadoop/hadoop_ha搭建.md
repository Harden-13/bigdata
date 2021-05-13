### hdfs

#### 1.预安装

##### a.环境准备

```
（1）修改IP
（2）修改主机名及主机名和IP地址的映射
（3）关闭防火墙
（4）ssh免密登录
（5）安装JDK，hadoop,zk配置环境变量等
 (6) hadoop用户启动hadoop；root启动zk
 (7) nn格式化不成功的时候，记得删除data 和 log目录
 (8) 所有hadoop配置文件同步
```

##### b,安装版本

```
hadoop3.1.3
zk3.5.7
jdk1.8.0_212
```

##### c.集群规划

| hadoop0         | hadoop1         | hadoop2     |
| --------------- | --------------- | ----------- |
| NameNode        | NameNode        | NameNode    |
| ZKFC            | ZKFC            | ZKFC        |
| JournalNode     | JournalNode     | JournalNode |
| DataNode        | DataNode        | DataNode    |
| ZK              | ZK              | ZK          |
| ResourceManager | ResourceManager |             |
| NodeManager     | NodeManager     | NodeManager |

#### 2.zk安装参照其文档,并启动

#### 3.配置hdfs ha集群

##### a.core-site.xml配置

```
<configuration>
	<!-- 指定NameNode的地址 -->
	<property>
    	<name>fs.defaultFS</name>
		<value>hdfs://mycluster</value>
	</property>
	<!-- 指定hadoop数据的存储目录 -->
	<property>
    	<name>hadoop.tmp.dir</name>
       	<value>/opt/module/hadoop-3.1.3/data</value>
	</property>

	<!-- 配置HDFS网页登录使用的静态用户为hadoop -->
	<property>
		<name>hadoop.http.staticuser.user</name>
		<value>hadoop</value>
	</property>
	<!-- 配置该atguigu(superUser)允许通过代理访问的主机节点 -->
	 <property>
		<name>hadoop.proxyuser.hadoop.hosts</name>
		<value>*</value>
	</property>
	<!-- 配置该atguigu(superUser)允许通过代理用户所属组 -->
	<property>
		<name>hadoop.proxyuser.hadoop.groups</name>
	   	<value>*</value>
	</property>
	<!-- 配置该atguigu(superUser)允许通过代理的用户-->
	<property>
		<name>hadoop.proxyuser.hadoop.groups</name>
	   	<value>*</value>
	</property>
	<property>
		<name>ha.zookeeper.quorum</name>
		<value>hadoop0:2181,hadoop1:2181,hadoop2:2181</value>
	</property>

</configuration>


```

##### b.hdfs-site.xml配置

```
<configuration>
	<!-- NameNode数据存储目录 -->
	<property>
		<name>dfs.namenode.name.dir</name>
		<value>file://${hadoop.tmp.dir}/name</value>
	</property>
	<!-- DataNode数据存储目录 -->
	<property>
		<name>dfs.datanode.data.dir</name>
		<value>file://${hadoop.tmp.dir}/data</value>
	</property>
	<!-- JournalNode数据存储目录 -->
	<property>
		<name>dfs.journalnode.edits.dir</name>
		<value>${hadoop.tmp.dir}/jn</value>
	</property>
	<!-- 完全分布式集群名称 -->
	<property>
		<name>dfs.nameservices</name>
		<value>mycluster</value>
	</property>
	<!-- 集群中NameNode节点都有哪些 -->
	<property>
		<name>dfs.ha.namenodes.mycluster</name>
		<value>nn1,nn2,nn3</value>
	</property>
	<!-- NameNode的RPC通信地址 -->
	<property>
		<name>dfs.namenode.rpc-address.mycluster.nn1</name>
		<value>hadoop0:8020</value>
	</property>
	<property>
		<name>dfs.namenode.rpc-address.mycluster.nn2</name>
		<value>hadoop1:8020</value>
	</property>
	<property>
		<name>dfs.namenode.rpc-address.mycluster.nn3</name>
		<value>hadoop2:8020</value>
	</property>
	<!-- NameNode的http通信地址 -->
	<property>
		<name>dfs.namenode.http-address.mycluster.nn1</name>
		<value>hadoop0:9870</value>
	</property>
	<property>
		<name>dfs.namenode.http-address.mycluster.nn2</name>
		<value>hadoop1:9870</value>
	</property>
	<property>
		<name>dfs.namenode.http-address.mycluster.nn3</name>
		<value>hadoop2:9870</value>
	</property>
	<!-- 指定NameNode元数据在JournalNode上的存放位置 -->
	<property>
		<name>dfs.namenode.shared.edits.dir</name>
		<value>qjournal://hadoop0:8485;hadoop1:8485;hadoop2:8485/mycluster</value>
	</property>
	<!-- 访问代理类：client用于确定哪个NameNode为Active -->
	<property>
		<name>dfs.client.failover.proxy.provider.mycluster</name>
		<value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
	</property>
	<!-- 配置隔离机制，即同一时刻只能有一台服务器对外响应 -->
	<property>
		<name>dfs.ha.fencing.methods</name>
		<value>sshfence</value>
	</property>
	<!-- 使用隔离机制时需要ssh秘钥登录-->
	<property>
		<name>dfs.ha.fencing.ssh.private-key-files</name>
		<value>/home/hadoop/.ssh/id_rsa</value>
	</property>
	<!-- 启用nn故障自动转移 -->
	<property>
		<name>dfs.ha.automatic-failover.enabled</name>
		<value>true</value>
	</property>
  </configuration>

```

##### c.hdfs命令启动

* 在各个JournalNode节点上，启动journalnode服务

```
hdfs --daemon start journalnode
```

* 在[nn1]上，对其进行格式化，并启

```
hdfs namenode -format
hdfs --daemon start namenode
```

* 在[nn2]和[nn3]上，同步nn1的元数据信息

```
hdfs namenode -bootstrapStandby
```

* 启动[nn2]和[nn3]

```
hdfs --daemon start namenode
```

* 备注

```
此时三个nn节点都是standby
```

* 所有节点上，启动datanode

```
hdfs --daemon start datanode
```

* 将[nn1]切换为Active

```
hdfs haadmin -transitionToActive nn1
```

* 查看是否Active

```
hdfs haadmin -getServiceState nn1
```

#### 4.HDFS-HA**自动故障转移**

##### a.core.site.xml,hdfs-site.xml

```
<!--core.site.xml 指定zkfc要连接的zkServer地址 -->
<property>
	<name>ha.zookeeper.quorum</name>
	<value>hadoop102:2181,hadoop103:2181,hadoop104:2181</value>
</property>
<!-- hdfs-site.xml启用nn故障自动转移 -->
<property>
	<name>dfs.ha.automatic-failover.enabled</name>
	<value>true</value>
</property>

```

##### b.关闭所有hdfs服务，病启动zk

```
#一台机器执行
stop-dfs.sh
#三台zk分别执行
zkServer.sh start
```

##### c.启动zk后，再初始化HA(hadoop0)在zk中状态：

```
# hadoop0执行
hdfs zkfc -formatZK
```

##### d 启动hdfs

```
# 任意一台集群中机器，检查是否服务都启动成功，否则在执行此命令
start-dfs.sh
```

##### e zkCli.sh检查nn选举节点

```
get -s /hadoop-ha/mycluster/ActiveStandbyElectorLock
```

##### f.验证

```
kill -9 namenode的进程id
```

### Yarn

#### 1.yarn-site,xml配置

```
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>

    <!-- 启用resourcemanager ha -->
    <property>
        <name>yarn.resourcemanager.ha.enabled</name>
        <value>true</value>
    </property>

    <!-- 声明两台resourcemanager的地址 -->
    <property>
        <name>yarn.resourcemanager.cluster-id</name>
        <value>cluster-yarn1</value>
    </property>
    <!--指定resourcemanager的逻辑列表-->
    <property>
        <name>yarn.resourcemanager.ha.rm-ids</name>
        <value>rm1,rm2</value>
    </property>
    <!-- ========== rm1的配置 ========== -->
    <!-- 指定rm1的主机名 -->
    <property>
        <name>yarn.resourcemanager.hostname.rm1</name>
        <value>hadoop0</value>
    </property>
    <!-- 指定rm1的web端地址 -->
    <property>
        <name>yarn.resourcemanager.webapp.address.rm1</name>
        <value>hadoop0:8088</value>
    </property>
    <!-- 指定rm1的内部通信地址 -->
    <property>
        <name>yarn.resourcemanager.address.rm1</name>
        <value>hadoop0:8032</value>
    </property>
    <!-- 指定AM向rm1申请资源的地址 -->
    <property>
        <name>yarn.resourcemanager.scheduler.address.rm1</name>
        <value>hadoop0:8030</value>
    </property>
    <!-- 指定供NM连接的地址 -->
    <property>
        <name>yarn.resourcemanager.resource-tracker.address.rm1</name>
        <value>hadoop0:8031</value>
    </property>
    <!-- ========== rm2的配置 ========== -->
    <!-- 指定rm2的主机名 -->
    <property>
        <name>yarn.resourcemanager.hostname.rm2</name>
        <value>hadoop1</value>
    </property>
    <property>
        <name>yarn.resourcemanager.webapp.address.rm2</name>
        <value>hadoop1:8088</value>
    </property>
    <property>
        <name>yarn.resourcemanager.address.rm2</name>
        <value>hadoop1:8032</value>
    </property>
    <property>
        <name>yarn.resourcemanager.scheduler.address.rm2</name>
        <value>hadoop1:8030</value>
    </property>
    <property>
        <name>yarn.resourcemanager.resource-tracker.address.rm2</name>
        <value>hadoop1:8031</value>
    </property>

    <!-- 指定zookeeper集群的地址 -->
    <property>
        <name>yarn.resourcemanager.zk-address</name>
        <value>hadoop0:2181,hadoop1:2181,hadoop2:2181</value>
    </property>

    <!-- 启用自动恢复 -->
    <property>
        <name>yarn.resourcemanager.recovery.enabled</name>
        <value>true</value>
    </property>

    <!-- 指定resourcemanager的状态信息存储在zookeeper集群 -->
    <property>
        <name>yarn.resourcemanager.store.class</name>
        <value>org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore</value>
    </property>
        <!-- 指定MR走shuffle -->
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
<!-- 指定ResourceManager的地址-->
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>hadoop1</value>
    </property>
<!-- 环境变量的继承 -->
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>
    </property>
<!-- yarn容器允许分配的最大最小内存 -->
    <property>
        <name>yarn.scheduler.minimum-allocation-mb</name>
        <value>512</value>
    </property>
    <property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>4096</value>
    </property>
    <!-- yarn容器允许管理的物理内存大小 -->
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>4096</value>
    </property>
<!-- 关闭yarn对物理内存和虚拟内存的限制检查 -->
    <property>
        <name>yarn.nodemanager.pmem-check-enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>false</value>
    </property>
</configuration>

```

#### 2.启动yarn

* rm1或者rm2执行

```
start-yarn.sh
```

* 查看服务状态

```
yarn rmadmin -getServiceState rm1
```

* 去zkCli.sh客户端查看ResourceManager选举锁节点内容

```
get -s /yarn-leader-election/cluster-yarn1/ActiveStandbyElectorLock
```



### HA原理

#### 1.HDFS

* 元数据管理方式

```
内存中各自保存一份元数据；
Edits日志只有Active状态的NameNode节点可以做写操作；
所有的NameNode都可以读取Edits；
共享的Edits放在一个共享存储中管理（qjournal和NFS两个主流实现）；

```

* zkfailover功能

```
实现了一个zkfailover，常驻在每一个namenode所在的节点，每一个zkfailover负责监控自己所在NameNode节点，利用zk进行状态标识，当需要进行状态切换时，由zkfailover来负责切换，切换时需要防止brain split现象的发生。
```

* 必须保证两个NameNode之间能够ssh无密码登录

* 隔离（Fence），即同一时刻仅仅有一个NameNode对外提供服务

#### 2.HA自动故障转移机制

```
自动故障转移为HDFS部署增加了两个新组件：ZooKeeper和ZKFailoverController（ZKFC）进程，如图3-20所示。ZooKeeper是维护少量协调数据，通知客户端这些数据的改变和监视客户端故障的高可用服务。HA的自动故障转移依赖于ZooKeeper的以下功能：
1．故障检测
集群中的每个NameNode在ZooKeeper中维护了一个会话，如果机器崩溃，ZooKeeper中的会话将终止，ZooKeeper通知另一个NameNode需要触发故障转移。
2．现役NameNode选择
ZooKeeper提供了一个简单的机制用于唯一的选择一个节点为active状态。如果目前现役NameNode崩溃，另一个节点可能从ZooKeeper获得特殊的排外锁以表明它应该成为现役NameNode。
ZKFC是自动故障转移中的另一个新组件，是ZooKeeper的客户端，也监视和管理NameNode的状态。每个运行NameNode的主机也运行了一个ZKFC进程，ZKFC负责：
1）健康监测
ZKFC使用一个健康检查命令定期地ping与之在相同主机的NameNode，只要该NameNode及时地回复健康状态，ZKFC认为该节点是健康的。如果该节点崩溃，冻结或进入不健康状态，健康监测器标识该节点为非健康的。
2）ZooKeeper会话管理
当本地NameNode是健康的，ZKFC保持一个在ZooKeeper中打开的会话。如果本地NameNode处于active状态，ZKFC也保持一个特殊的znode锁，该锁使用了ZooKeeper对短暂节点的支持，如果会话终止，锁节点将自动删除。
3）基于ZooKeeper的选择
如果本地NameNode是健康的，且ZKFC发现没有其它的节点当前持有znode锁，它将为自己获取该锁。如果成功，则它已经赢得了选择，并负责运行故障转移进程以使它的本地NameNode为Active

```

### 命令使用

#### 1.ha中访问hdfs

```
hadoop fs -put /opt/hive.txt  hdfs://hadoop2:8020/hive/
hadoop fs -put /opt/hive.txt  hdfs://mycluster:8020/hive/
```

