##### Druid Architecture

1. ##### architecture overview

```
​``` python
实时节点(realtime node) ：及时摄入实时数据，以及生成segment数据文件
历史节点(historical node) : 加载已经生成好的数据文件，以供数据查询
查询节点(broker node) : 对外提供数据查询，并同时从实时节点与历史节点查询数据，合并后返回调用方
协调节点(coordinator node) : 负责历史节点的数据负载均衡，以及通过规则管理数据生命周期，zookeeper
元数据库(metastore) : 存储druid集群的原始信息，比如segment的相关信息，一般使用mysql
分布式协调服务(coordination) : 为durid集群提供一致性协调服务组件，通常为zookeeper
数据文件库存储(deepstorage) : 存放生成segment文件，并提供历史节点下载，对于单点集群可以是本地磁盘，分布式一般是hdfs
​```
```

##### druid component

```
Broker：接收来自外部客户端的查询，并将这些查询转发到Historical节点。当Broker节点收到结果，它们将合并这些结果并将它们返回给调用者。由于了解拓扑，Broker节点使用Zookeeper来确定哪些Historical节点的存在。

IndexServices：Indexing Service是负责“生产”Segment的高可用、分布式、Master/Slave架构服务。主要由三类组件构成：负责运行索引任务(indexing task)的Peon，负责控制Peon的MiddleManager，负责任务分发给MiddleManager的Overlord

Overlord：Overlord负责接受任务、协调任务的分配、创建任务锁以及收集、返回任务运行状态给调用者。当集群中有多个Overlord时，则通过选举算法产生Leader，其他Follower作为备份。
Overlord监控UI ：http://overlord_ip:8081

Middle Manager和Peon：MiddleManager负责接收Overlord分配的索引任务，同时创建新的进程用于启动Peon来执行索引任务，每一个MiddleManager可以运行多个Peon实例。

Peon是Indexing Service的最小工作单元，也是索引任务的具体执行者，所有当前正在运行的Peon任务都可以通过Overlord提供的web可视化界面进行访问。

middleManager Overlord监控UI：http://middleManager_ip:8090/console.html

Coordinator：监控Historical节点组，以确保数据可用、可复制，并且在一般的“最佳”配置。它们通过从MySQL读取数据段的元数据信息，来决定哪些数据段应该在集群中被加载，使用Zookeeper来确定哪个Historical节点存在，并且创建Zookeeper条目告诉Historical节点加载和删除新数据段。

Historical：是对“historical”数据（非实时）进行处理存储和查询的地方。Historical节点响应从Broker节点发来的查询，并将结果返回给broker节点。它们在Zookeeper的管理下提供服务，并使用Zookeeper监视信号加载或删除新数据段。

RealTime：负责监听输入数据流并让其在内部的Druid系统立即获取，Realtime节点同样只响应broker节点的查询请求，返回查询结果到broker节点。旧数据会被从Realtime节点转存Historical节点。
```

![](https://github.com/Harden-13/bigdata/blob/master/druid/druid.png)

```
为了加速数据库的访问，大多传统的关系型数据库都会使用特殊的数据结构来帮助查找数据，这种数据结构叫做索引(index)，传统关系型数据库，考虑到经常需要范围查找某一项数据，因此其索引一般不使用hash算法，而使用树(tree)结构，B+树及其衍生树是被用的比较多的索引树
B+树特点 ：每个树节点值放键值，不存放数值，叶子节点放数值，树的度(degree)比较大，但是高度(high)低，提高了效率
叶子节点(没有子节点)放数值，并按照值大小顺序排序，且带指向的相邻节点的指针，高效进行区间查询，叶子节点与根距离相同，任何查询效率都相似
B+树的数据更新从叶子节点开始，更新过程已较小的代价实现自平衡
```

##### Lsm-tree

```
特点 ：使用2部分类树的数据结构来存储数据并提供查询能力，C0树放在内存缓存种(mentable),负责接受新的数据插入更新以及读请求，直接在内存中对数据进行排序，C1树存在硬盘上(sstable)，它们是由存在内存中的C0树冲写而成的，主要负责读操作，有序不可被更改
适用于 ：数据插入操作多于数据更新，删除操作与读操作
解决不适合读操作的方法 ： 定期将硬盘上小的sstable合并(merge|compaction操作)成大的sstable，减少sstable数量，平时的更新，删除不会在原有数据更改，只会讲要更新删除操作加到当前的数据文件末端，只有在sstable合并的时候才会将重复的操作更新去重合并
```

##### wal

```
使用日志文件恢复故障，所有新插入与更新操作都首先会被记录到commit log,该操作叫做wal(write ahead log),然后在写道memtable,当到达一定条数时数据从memtable冲写道sstab，memtable,sstable可同时提供查询。memtable出现故障可从sstable,commit log中将数据恢复
```

![](https://github.com/Harden-13/bigdata/blob/master/druid/segment.png)

##### indexing service

```
除了通过realtime节点产出segment外，druid还提供了一组名为索引服务(indexing,service)的组件同样能够制造出segment数据文件，相比realtime节点生产segment数据文件的方式，除了能对数据pull外，还支持push
```

##### indexing service arch

```
以主从(master-slave)结构作为其架构方式，其中统治节点(overload)为主节点,中间管理者(middle manager)从节点
1.overload节点作为服务的主节点，对外负责接收任务请求，对内负责将任务分解并下发到从节点即中间节点
	1.1本地模式 ：默认模式。在该模式下统治节点(overload)不仅负责集群的任务协调分配工作，也负责启动一些苦工(peon)来完成一部分具体任务
	1.2远程模式 ： overload & middle manager运行在不同节点上，它仅负责集群任务协调分配，并提供restful的访问方法，客户端通过http post请求向overload提交任务
```

![](https://github.com/Harden-13/bigdata/blob/master/druid/indexing.png)



