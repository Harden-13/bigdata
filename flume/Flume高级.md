## Flume高级

### 1.flume事务

#### 1.事务原理

* 流程

```
source--batch data--> ① 推送事务-->channel-->②拉取事务-->sink-->hdfs
```

* put推送事务流程

```
doput将批数据先写入临时缓冲区putList
docommit检查channel内存队列中是否足够合并
dorollbackChannel内存队列空间不足，回滚数据
```

* take事务流程

```
doTake将批数据取到临时缓冲区TakeList,并将数据发送到hdfs
docommit如果数据全部发送成功，则清楚临时缓冲区takelist
dorollback数据发送中出现异常，rollback将临时缓冲区takelist中的数据归还给channel内存队列，并有可能造成数据重复
```

#### 2.agent内部原理

* 原理图

![agent原理](C:\Users\lenovo\Desktop\bigdata\flume\agent原理.png)



##### 1.**ChannelSelector**

* 分类

```
ChannelSelector的作用就是选出Event将要被发往哪个Channel。其共有两种类型，分别是Replicating（复制）和Multiplexing（多路复用）。
```

###### 1.ReplicatingSelector

```
ReplicatingSelector会将同一个Event发往所有的Channel
```

###### 2.Multiplexing

```
Multiplexing会根据相应的原则，将不同的Event发往不同的Channel。
```

##### 2.**SinkProcessor**

* 分类

```
SinkProcessor共有三种类型，分别是DefaultSinkProcessor、LoadBalancingSinkProcessor和FailoverSinkProcessor
```

###### 1.DefaultSinkProcessor

```
DefaultSinkProcessor对应的是单个的Sink
```

###### 2.LoadBalancingSinkProcessor

```
LoadBalancingSinkProcessor可以实现负载均衡的功能，LoadBalancingSinkProcessor和FailoverSinkProcessor对应的是Sink Group，
```

###### 3.FailoverSinkProcessor

```
FailoverSinkProcessor可以错误恢复的功能。LoadBalancingSinkProcessor和FailoverSinkProcessor对应的是Sink Group，
```

### 2.案例

#### 1.复制和多路复用

##### 1. 实现原理

* 分析

```
Flume-1监控文件变动，Flume-1将变动内容传递给Flume-2，
Flume-2负责存储到HDFS。同时Flume-1将变动内容传递给Flume-3，
Flume-3负责输出到Local FileSystem
```

* 原理图

![案例1](C:\Users\lenovo\Desktop\bigdata\flume\案例1.png)

##### 2.配置文件

* 创建flume-file-flume.conf

```
配置1个接收日志文件的source和两个channel、两个sink，分别输送给flume-flume-hdfs和flume-flume-dir。
```

```
a1.sources = r1
a1.sinks = k1 k2
a1.channels = c1 c2
# 将数据流复制给所有channel
a1.sources.r1.selector.type = replicating

# Describe/configure the source
a1.sources.r1.type = exec
a1.sources.r1.command = tail -F /opt/module/hive/logs/hive.log
a1.sources.r1.shell = /bin/bash -c

# Describe the sink
# sink端的avro是一个数据发送者
a1.sinks.k1.type = avro
a1.sinks.k1.hostname = hadoop0
a1.sinks.k1.port = 4141

a1.sinks.k2.type = avro
a1.sinks.k2.hostname = hadoop0
a1.sinks.k2.port = 4142

# Describe the channel
a1.channels.c1.type = memory
a1.channels.c1.capacity = 1000
a1.channels.c1.transactionCapacity = 100

a1.channels.c2.type = memory
a1.channels.c2.capacity = 1000
a1.channels.c2.transactionCapacity = 100

# Bind the source and sink to the channel
a1.sources.r1.channels = c1 c2
a1.sinks.k1.channel = c1
a1.sinks.k2.channel = c2
```

*  flume-flume-hdfs.conf
* * 配置上级Flume输出的Source，输出是到HDFS的Sink。

```
a2.sources = r1
a2.sinks = k1
a2.channels = c1

# Describe/configure the source
# source端的avro是一个数据接收服务
a2.sources.r1.type = avro
a2.sources.r1.bind = hadoop0
a2.sources.r1.port = 4141

# Describe the sink
a2.sinks.k1.type = hdfs
a2.sinks.k1.hdfs.path = hdfs://mycluster:8020/flume2/%Y%m%d/%H
#上传文件的前缀
a2.sinks.k1.hdfs.filePrefix = flume2-
#是否按照时间滚动文件夹
a2.sinks.k1.hdfs.round = true
#多少时间单位创建一个新的文件夹
a2.sinks.k1.hdfs.roundValue = 1
#重新定义时间单位
a2.sinks.k1.hdfs.roundUnit = hour
#是否使用本地时间戳
a2.sinks.k1.hdfs.useLocalTimeStamp = true
#积攒多少个Event才flush到HDFS一次
a2.sinks.k1.hdfs.batchSize = 100
#设置文件类型，可支持压缩
a2.sinks.k1.hdfs.fileType = DataStream
#多久生成一个新的文件
a2.sinks.k1.hdfs.rollInterval = 600
#设置每个文件的滚动大小大概是128M
a2.sinks.k1.hdfs.rollSize = 134217700
#文件的滚动与Event数量无关
a2.sinks.k1.hdfs.rollCount = 0

# Describe the channel
a2.channels.c1.type = memory
a2.channels.c1.capacity = 1000
a2.channels.c1.transactionCapacity = 100

# Bind the source and sink to the channel
a2.sources.r1.channels = c1
a2.sinks.k1.channel = c1

```

* flume-flume-dir.conf
* * 配置上级Flume输出的Source，输出是到本地目录的Sink

```
a3.sources = r1
a3.sinks = k1
a3.channels = c2

# Describe/configure the source
a3.sources.r1.type = avro
a3.sources.r1.bind = hadoop0
a3.sources.r1.port = 4142

# Describe the sink
a3.sinks.k1.type = file_roll
a3.sinks.k1.sink.directory = /opt/src/flume3

# Describe the channel
a3.channels.c2.type = memory
a3.channels.c2.capacity = 1000
a3.channels.c2.transactionCapacity = 100

# Bind the source and sink to the channel
a3.sources.r1.channels = c2
a3.sinks.k1.channel = c2

```

#### 2.负载均衡故障转移

##### 1.实现原理

* 分析

```
Flume1监控一个端口，其sink组中的sink分别对接Flume2和Flume3，采用FailoverSinkProcessor，实现故障转移的功能
```

* 原理图

![案例2](C:\Users\lenovo\Desktop\bigdata\flume\案例2.png)

##### 2.配置文件

* flume-netcat-flume.conf

```
配置1个netcat source和1个channel、1个sink group（2个sink），分别输送给flume-flume-console1和flume-flume-console2。
```

```
a1.sources = r1
a1.channels = c1
a1.sinkgroups = g1
a1.sinks = k1 k2

# Describe/configure the source
a1.sources.r1.type = netcat
a1.sources.r1.bind = localhost
a1.sources.r1.port = 44444

a1.sinkgroups.g1.processor.type = failover
a1.sinkgroups.g1.processor.priority.k1 = 5
a1.sinkgroups.g1.processor.priority.k2 = 10
a1.sinkgroups.g1.processor.maxpenalty = 10000

# Describe the sink
a1.sinks.k1.type = avro
a1.sinks.k1.hostname = hadoop0
a1.sinks.k1.port = 4141

a1.sinks.k2.type = avro
a1.sinks.k2.hostname = hadoop0
a1.sinks.k2.port = 4142

# Describe the channel
a1.channels.c1.type = memory
a1.channels.c1.capacity = 1000
a1.channels.c1.transactionCapacity = 100

# Bind the source and sink to the channel
a1.sources.r1.channels = c1
a1.sinkgroups.g1.sinks = k1 k2
a1.sinks.k1.channel = c1
a1.sinks.k2.channel = c1

```

* flume-flume-console1.conf
* * 配置上级Flume输出的Source，输出是到本地控制台。

```
# Name the components on this agent
a2.sources = r1
a2.sinks = k1
a2.channels = c1

# Describe/configure the source
a2.sources.r1.type = avro
a2.sources.r1.bind = hadoop0
a2.sources.r1.port = 4141

# Describe the sink
a2.sinks.k1.type = logger

# Describe the channel
a2.channels.c1.type = memory
a2.channels.c1.capacity = 1000
a2.channels.c1.transactionCapacity = 100

# Bind the source and sink to the channel
a2.sources.r1.channels = c1
a2.sinks.k1.channel = c1

```

* flume-flume-console2.conf
* * 配置上级Flume输出的Source，输出是到本地控制台

```
# Name the components on this agent
a3.sources = r1
a3.sinks = k1
a3.channels = c2

# Describe/configure the source
a3.sources.r1.type = avro
a3.sources.r1.bind = hadoop0
a3.sources.r1.port = 4142

# Describe the sink
a3.sinks.k1.type = logger

# Describe the channel
a3.channels.c2.type = memory
a3.channels.c2.capacity = 1000
a3.channels.c2.transactionCapacity = 100

# Bind the source and sink to the channel
a3.sources.r1.channels = c2
a3.sinks.k1.channel = c2

```

* 实验测试

```
//使用netcat工具向本机的44444端口发送内容
$ nc localhost 44444
//查看Flume2及Flume3的控制台打印日志
//将Flume2 kill，观察Flume3的控制台打印情况。
注：使用jps -ml查看Flume进程。

```

#### 3.聚合案例

##### 1.实现原理

* 目标

```
hadoop0上的Flume-1监控文件/opt/module/group.log，
hadoop1上的Flume-2监控某一个端口的数据流，Flume-1与Flume-2将数据发送给Flume-3，
hadoop2上的Flume-3将最终数据打印到控制台
```

* 原理图

![案例3](C:\Users\lenovo\Desktop\bigdata\flume\案例3.png)

##### 2.配置文件

* hadoop0 配置文件
* * Source用于监控hive.log文件，配置Sink输出数据到下一级Flume

```
a1.sources = r1
a1.sinks = k1
a1.channels = c1

# Describe/configure the source
a1.sources.r1.type = exec
a1.sources.r1.command = tail -F /opt/module/group.log
a1.sources.r1.shell = /bin/bash -c

# Describe the sink
a1.sinks.k1.type = avro
a1.sinks.k1.hostname = hadoop2
a1.sinks.k1.port = 4141

# Describe the channel
a1.channels.c1.type = memory
a1.channels.c1.capacity = 1000
a1.channels.c1.transactionCapacity = 100

# Bind the source and sink to the channel
a1.sources.r1.channels = c1
a1.sinks.k1.channel = c1

```

* hadoop1 flume2-netcat-flume.conf
* * Source监控端口44444数据流，配置Sink数据到下一级Flume：

```
a2.sources = r1
a2.sinks = k1
a2.channels = c1

# Describe/configure the source
a2.sources.r1.type = netcat
a2.sources.r1.bind = hadoop1
a2.sources.r1.port = 44444

# Describe the sink
a2.sinks.k1.type = avro
a2.sinks.k1.hostname = hadoop2
a2.sinks.k1.port = 4141

# Use a channel which buffers events in memory
a2.channels.c1.type = memory
a2.channels.c1.capacity = 1000
a2.channels.c1.transactionCapacity = 100

# Bind the source and sink to the channel
a2.sources.r1.channels = c1
a2.sinks.k1.channel = c1

```

* hadoop2 **flume3-flume-logger.conf**
* * source用于接收flume1与flume2发送过来的数据流，最终合并后sink到控制台。

```
a3.sources = r1
a3.sinks = k1
a3.channels = c1

# Describe/configure the source
a3.sources.r1.type = avro
a3.sources.r1.bind = hadoop2
a3.sources.r1.port = 4141

# Describe the sink
# Describe the sink
a3.sinks.k1.type = logger

# Describe the channel
a3.channels.c1.type = memory
a3.channels.c1.capacity = 1000
a3.channels.c1.transactionCapacity = 100

# Bind the source and sink to the channel
a3.sources.r1.channels = c1
a3.sinks.k1.channel = c1

```

* 启动

```
2-->1-->0
```

