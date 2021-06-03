### Flume

#### 1.概况

```
flume传递数据，包含三个组件：source，channel，sink.
webserver-->agent(source->channel->sink)-->hdfs
channel保证了一旦数据源过快，sink来不及消费保存数据造成数据丢失
```

#### 2. 基础架构

* agent

```
Agent是一个JVM进程，它以事件的形式将数据从源头送至目的。
Agent主要有3个部分组成，Source、Channel、Sink。
```

* Source

```
Source是负责接收数据到Flume Agent的组件。Source组件可以处理各种类型、各种格式的日志数据
```

* sink

```
Sink不断地轮询Channel中的事件且批量地移除它们，并将这些事件批量写入到存储或索引系统、或者被发送到另一个Flume Agent。
Sink组件目的地包括hdfs、file、HBase、自定义。
```

* channel

```
Channel是位于Source和Sink之间的缓冲区。因此，Channel允许Source和Sink运作在不同的速率上。Channel是线程安全的，可以同时处理几个Source的写入操作和几个Sink的读取操作
```

* channel分类

```
自带两种Channel：Memory Channel和File
Channel。
Memory Channel是内存中的队列。Memory Channel在不需要关心数据丢失的情景下适用。如果需要关心数据丢失，那么Memory Channel就不应该使用，因为程序死亡、机器宕机或者重启都会导致数据丢失。
File Channel将所有事件写到磁盘。因此在程序关闭或机器宕机的情况下不会丢失数据。

```

* event

```
传输单元，Flume数据传输的基本单元，以Event的形式将数据从源头送至目的地。Event由Header和Body两部分组成，Header用来存放该event的一些属性，为K-V结构，Body用来存放该条数据，形式为字节数组
```

#### 3.基础搭建

##### 1.基础环境

```
flume1.9.0
rm -fr guava-11.0.2.jar //删除以兼容Hadoop 3.1.3
```

##### 2.搭建过程

```
tar -xvf apache-flume-1.9.0-bin.tar.gz -C /opt/module/
ln -s apache-flume-1.9.0-bin flume
rm -fr lib/guava-11.0.2.jar
# 环境变量
#FLUME_HOME
export FLUME_HOME=/opt/module/apache-flume-1.9.0-bin
export PATH=$PATH:$FLUME_HOME/bin
```

##### 3.配置文件解析

**a1: 表示agent的名称**

**r1:表示a1的Source的名称**

**k1:表示a1的Sink的名称**

**c1:表示a1的channel的名称**

****

a1.sources.r1.channels = c1
a1.sinks.k1.channel = c1

**表示将r1和c1连接起来**

**表示将k1和c1连接起来**

```
# example.conf: A single-node Flume 
# job/flume-netcat-logger.conf
a1.sources = r1
a1.sinks = k1
a1.channels = c1

# Describe/configure the source
a1.sources.r1.type = netcat
a1.sources.r1.bind = localhost
a1.sources.r1.port = 44444

# Describe the sink
a1.sinks.k1.type = logger

# Use a channel which buffers events in memory
a1.channels.c1.type = memory
a1.channels.c1.capacity = 1000  				//总容量1000的event
a1.channels.c1.transactionCapacity = 100		//收集到100条数据在进行提交

# Bind the source and sink to the channel
a1.sources.r1.channels = c1
a1.sinks.k1.channel = c1
```

##### 4.启动命令

* 第一种

```
 flume-ng agent --conf conf/ --name a1 --conf-file job/flume-netcat-logger.conf -Dflume.root.logger=INFO,console
```

* 第二种

```
flume-ng agent -c conf/ -n a1 -f job/flume-netcat-logger.conf -Dflume.root.logger=INFO,console
```

* 参数解释说明

```
--conf/-c：表示配置文件存储在conf/目录
--name/-n：表示给agent起名为a1
--conf-file/-f：flume本次启动读取的配置文件是在job文件夹下的flume-telnet.conf文件。
-Dflume.root.logger=INFO,console ：-D表示flume运行时动态修改flume.root.logger参数属性值，并将控制台日志打印级别设置为INFO级别。日志级别包括:log、info、warn、error。
```

#### 4.案例

##### 1.实时监控单个追加文件

* 实时监控Hive日志，并上传到HDFS中

* * Flume要想将数据输出到HDFS，依赖Hadoop相关jar包

```
确认Hadoop和Java环境变量配置正确
```

* 配置文件

```
[hadoop@hadoop0 job]$ cat flume-file-hdfs.conf
a2.sources = r2
a2.sinks = k2
a2.channels = c2

# Describe/configure the source
a2.sources.r2.type = exec
a2.sources.r2.command = tail -F /opt/module/hive/logs/hive.log

# Describe the sink
a2.sinks.k2.type = hdfs
#hadoop ha的地址
a2.sinks.k2.hdfs.path = hdfs://mycluster:8020/flume/%Y%m%d/%H
#上传文件的前缀
a2.sinks.k2.hdfs.filePrefix = logs-
#是否按照时间滚动文件夹
a2.sinks.k2.hdfs.round = true
#多少时间单位创建一个新的文件夹
a2.sinks.k2.hdfs.roundValue = 1
#重新定义时间单位
a2.sinks.k2.hdfs.roundUnit = hour
#是否使用本地时间戳
a2.sinks.k2.hdfs.useLocalTimeStamp = true
#积攒多少个Event才flush到HDFS一次
a2.sinks.k2.hdfs.batchSize = 100
#设置文件类型，可支持压缩
a2.sinks.k2.hdfs.fileType = DataStream
#多久生成一个新的文件
a2.sinks.k2.hdfs.rollInterval = 60
#设置每个文件的滚动大小
a2.sinks.k2.hdfs.rollSize = 134217700
#文件的滚动与Event数量无关
a2.sinks.k2.hdfs.rollCount = 0

# Use a channel which buffers events in memory
a2.channels.c2.type = memory
#channel存储的最大的数量
a2.channels.c2.capacity = 1000
#每次从source到sink的传输数量
a2.channels.c2.transactionCapacity = 100
#所有的events在channel中允许的最大的bytes of memory。仅仅计算的events body
a2.channels.c2.byteCapacity = 800000
# event增加或者移除的超时时间
a2.channels.c2.keep-alive = 60
# Bind the source and sink to the channel
a2.sources.r2.channels = c2
a2.sinks.k2.channel = c2
```

* 感悟和总结

```
1.启动flume后，在hdfs会生成一个.tmp结尾的文件表示正在使用
2.不会立即写入
```

##### 2.**监听整个目录的文件，并上传至HDFS**

* spooldir

```
在使用Spooling Directory Source时，不要在监控目录中创建并持续修改文件；上传完成的文件会以.COMPLETED结尾；被监控文件夹每500毫秒扫描一次文件变动。
```

* 配置文件

```
[hadoop@hadoop0 job]$ cat flume-directory-hdfs.conf
a3.sources = r3
a3.sinks = k3
a3.channels = c3

# Describe/configure the source
a3.sources.r3.type = spooldir
a3.sources.r3.spoolDir = /opt/module/flume/upload
a3.sources.r3.fileSuffix = .COMPLETED
a3.sources.r3.fileHeader = true
#忽略所有以.tmp结尾的文件，不上传
a3.sources.r3.ignorePattern = ([^ ]*\.tmp)

# Describe the sink
a3.sinks.k3.type = hdfs
a3.sinks.k3.hdfs.path = hdfs://mycluster:8020/flume/upload/%Y%m%d/%H
#上传文件的前缀
a3.sinks.k3.hdfs.filePrefix = upload-
#是否按照时间滚动文件夹
a3.sinks.k3.hdfs.round = true
#多少时间单位创建一个新的文件夹
a3.sinks.k3.hdfs.roundValue = 1
#重新定义时间单位
a3.sinks.k3.hdfs.roundUnit = hour
#是否使用本地时间戳
a3.sinks.k3.hdfs.useLocalTimeStamp = true
#积攒多少个Event才flush到HDFS一次
a3.sinks.k3.hdfs.batchSize = 100
#设置文件类型，可支持压缩
a3.sinks.k3.hdfs.fileType = DataStream
#多久生成一个新的文件
a3.sinks.k3.hdfs.rollInterval = 60
#设置每个文件的滚动大小大概是128M
a3.sinks.k3.hdfs.rollSize = 134217700
#文件的滚动与Event数量无关
a3.sinks.k3.hdfs.rollCount = 0

# Use a channel which buffers events in memory
a3.channels.c3.type = memory
a3.channels.c3.capacity = 1000
a3.channels.c3.transactionCapacity = 100

# Bind the source and sink to the channel
a3.sources.r3.channels = c3
a3.sinks.k3.channel = c3

```

* 实验心得

```
1.先要创建upload目录
2.启动flume后，目录下的文件会立即.complete 在hdfs中合并到一个以tmp结尾的当前文件
3.upload创建文件可以上传到hdfs（要注意权限问题，hadoop用户启动但是复制root权限的文件无法上传）
4.此时在向upload的文件中追加内容，不会上传到hdfs
```

##### 3.实时监控目录下的多个追加文件

* Taildir Source

```
Taildir Source适合用于监听多个实时追加的文件，并且能够实现断点续传。
```

* 配置

```
[hadoop@hadoop0 job]$ cat flume-taildir-hdfs.conf
a3.sources = r3
a3.sinks = k3
a3.channels = c3

# Describe/configure the source
a3.sources.r3.type = TAILDIR
#实现断点续传的位置信息
a3.sources.r3.positionFile = /opt/module/flume/tail_dir.json
a3.sources.r3.filegroups = f1 f2
#监控的目录
a3.sources.r3.filegroups.f1 = /opt/module/flume/files/.*file.*
a3.sources.r3.filegroups.f2 = /opt/module/flume/files2/.*log.*

# Describe the sink
a3.sinks.k3.type = hdfs
a3.sinks.k3.hdfs.path = hdfs://mycluster:8020/flume/upload2/%Y%m%d/%H
#上传文件的前缀
a3.sinks.k3.hdfs.filePrefix = upload-
#是否按照时间滚动文件夹
a3.sinks.k3.hdfs.round = true
#多少时间单位创建一个新的文件夹
a3.sinks.k3.hdfs.roundValue = 1
#重新定义时间单位
a3.sinks.k3.hdfs.roundUnit = hour
#是否使用本地时间戳
a3.sinks.k3.hdfs.useLocalTimeStamp = true
#积攒多少个Event才flush到HDFS一次
a3.sinks.k3.hdfs.batchSize = 100
#设置文件类型，可支持压缩
a3.sinks.k3.hdfs.fileType = DataStream
#多久生成一个新的文件
a3.sinks.k3.hdfs.rollInterval = 60
#设置每个文件的滚动大小大概是128M
a3.sinks.k3.hdfs.rollSize = 134217700
#文件的滚动与Event数量无关
a3.sinks.k3.hdfs.rollCount = 0

# Use a channel which buffers events in memory
a3.channels.c3.type = memory
a3.channels.c3.capacity = 1000
a3.channels.c3.transactionCapacity = 100

# Bind the source and sink to the channel
a3.sources.r3.channels = c3
a3.sinks.k3.channel = c3

```

* 实验心得

```
Linux中储存文件元数据的区域就叫做inode，每个inode都有一个号码，操作系统用inode号码来识别不同的文件，Unix/Linux系统内部不使用文件名，而使用inode号码来识别文件
```

```
flume的传输数量通过配置文件来控制
```





### old-example ：本地日志文件打到kafka

````
Spool监测配置的目录下新增的文件，并将文件中的数据读取出来。需要注意两点：
1) 拷贝到spool目录下的文件不可以再打开编辑。
2) spool目录下不可包含相应的子目录
exec
1) 能够监控文件，并且追加文件，
2) 目录下的多个文件
````

```
##下载1.7
wget http://archive.apache.org/dist/flume/1.7.0/apache-flume-1.7.0-bin.tar.gz
##解压缩并修改目录名
tar -xvf apache-flume-1.7.0-bin.tar.gz /usr/local/  && mv apache-flume-1.7.0 flume
##修改配置文件
echo "export JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk.x86_64/" >>/usr/local/flume/conf/flume-env.sh
##启动flume
/usr/local/flume/bin/flume-ng agent  -c /usr/local/flume/conf -f /usr/local/flume/conf/dashbaordReport.conf  -Dflume.root.logger=ERROR,console -n agent
##在kafka集群其中一台创建topic
/usr/local/kafka/bin/kafka-topics.sh --create --zookeeper 192.168.10.10:2181, 192.168.10.11:2181,192.168.10.12:2181  --replication-factor 2 --partitions 9 --topic kafka_topic
```

```
##agent代理名称
agent.sources = seqGenSrc
agent.channels = memoryChannel
agent.sinks = loggerSink
##配置source
agent.sources.seqGenSrc.type = spooldir
agent.sources.seqGenSrc.spoolDir = /data/logs
agent.sources.seqGenSrc.channels = memoryChannel
agent.sources.seqGenSrc.fileHeader = true
##配置channel
agent.channels.memoryChannel.type = memory
agent.channels.memoryChannel.capacity = 1000000
agent.channels.memoryChannel.keep-alive = 60
##配置sink
agent.sinks.loggerSink.channel = memoryChannel
agent.sinks.loggerSink.type = org.apache.flume.sink.kafka.KafkaSink
agent.sinks.loggerSink.kafka.topic = kafka_topic
agent.sinks.loggerSink.kafka.bootstrap.servers = 192.168.10.10:9092,192.168.10.11:9092,192.168.10.12:9092
agent.sinks.loggerSink.kafka.flumeBatchSize = 20
agent.sinks.loggerSink.kafka.producer.acks = 1
agent.sinks.loggerSink.kafka.producer.linger.ms = 1
agent.sinks.loggerSink.kafka.producer.compression.type = snappy  #Snappy是用C++开发的压缩和解压缩开发包，旨在提供高速压缩速度和合理的压缩率
```

```
###exec example 1  ;this is event 
agent.sources.seqGenSrc.type = exec
agent.sources.seqGenSrc.shell = /bin/bash -c
agent.sources.seqGenSrc.command = for i in /path/*.txt; do cat $i; done
#agent.sources.seqGenSrc.command = tail -F /data/logs/infoserver/`date +%Y%m%d`.log

###eexec example 2 ;this is streaming
从不断追加的日志文件录入flume
agent.sources.seqGenSrc.type = exec
agent.sources.seqGenSrc.command = tail -F /data/logs/infoserver/access.log
```
