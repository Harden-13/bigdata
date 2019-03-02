##### kafka basic

```
1、消费者：（Consumer）：从消息队列中请求消息的客户端应用程序
2、生产者：（Producer）  ：向broker发布消息的应用程序
3、AMQP服务端（broker）：用来接收生产者发送的消息并将这些消息路由给服务器中的队列，便于kafka将生产者发送的消息，动态的添加到磁盘并给每一条消息一个偏移量，所以对于kafka	一个broker就是一个应用程序的实例
4.主题（topic）：在工程中一个业务就是一个主题
5.分区（partition）：分区是kafka消息队列组织的最小单位,一个Topic中的消息数据按照多个分区组织;
kafka分区是提高kafka性能的关键所在,增加分区，提高性能
备注：：：动态扩容通过zookeeper实现，kafka增加和减少服务器都会在Zookeeper节点上触发相应的事件kafka系统会捕获这些事件，进行新一轮的负载均衡，客户端也会捕获这些事件来进行新一轮的处理
```

##### zookeeper setup

<span style='color:red'>1.Kafka集群是把状态保存在Zookeeper中的，首先要搭建Zookeeper集群。</span>

```
#yum install java-1.8*
#cd /opt/software && wget https://archive.apache.org/dist/zookeeper/stable/zookeeper-3.4.12.tar.gz && tar -xvf zookeeper-3.4.12.tar.gz -C /opt/ && ln -s zookeeper-3.4.12.tar.gz zookeeper && cd /opt/zookeeper/config
#cp zoo_sample.cfg zoo.cfg
#echo "1" >/opt/zookeeper/zkdata/myid
#cd ../bin && ./zkServer.sh start
```

<span style='color:red'>2.配置文件解写</span>

```
#tickTime：
这个时间是作为 Zookeeper 服务器之间或客户端与服务器之间维持心跳的时间间隔，也就是每个 tickTime 时间就会发送一个心跳。
#initLimit：
这个配置项是用来配置 Zookeeper 接受客户端（这里所说的客户端不是用户连接 Zookeeper 服务器的客户端，而是 Zookeeper 服务器集群中连接到 Leader 的 Follower 服务器）初始化连接时最长能忍受多少个心跳时间间隔数。当已经超过 5个心跳的时间（也就是 tickTime）长度后 Zookeeper 服务器还没有收到客户端的返回信息，那么表明这个客户端连接失败。总的时间长度就是 5*2000=10 秒
#syncLimit：
这个配置项标识 Leader 与Follower 之间发送消息，请求和应答时间长度，最长不能超过多少个 tickTime 的时间长度，总的时间长度就是5*2000=10秒
#dataDir：
快照日志的存储路径；下面有个myid 文件需要指定 server.x的具体数字
#dataLogDir：
事物日志的存储路径，如果不配置这个那么事物日志会默认存储到dataDir制定的目录，这样会严重影响zk的性能，当zk吞吐量较大的时候，产生的事物日志、快照日志太多
#clientPort：
这个端口就是客户端连接 Zookeeper 服务器的端口，Zookeeper 会监听这个端口，接受客户端的访问请求。修改他的端口改大点
#server.1=192.168.10.10:2888:3888
server.1 这个1是服务器的标识也可以是其他的数字， 表示这个是第几号服务器，用来标识服务器，这个标识要写到快照目录下面myid文件里
192.168.10.10为集群里的IP地址，第一个端口是master和slave之间的通信端口，默认是2888，第二个端口是leader选举的端口，集群刚启动的时候选举或者leader挂掉之后进行新的选举的端口默认是3888
```

##### kafka setup

```
#cd /opt/software && wget https://archive.apache.org/dist/kafka/0.9.0.1/kafka_2.11-0.9.0.1.tgz && tar -xvf kafka_2.11-0.9.0.1.tgz -C /opt/ && ln -s kafka_2.11-0.9.0.1.tgz kafka && cd /opt/kafka/bin
# /opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties
```

<span style='color:red'>1.配置文件解析</span>

```
broker.id=0  #当前机器在集群中的唯一标识，和zookeeper的myid性质一样
port=9092 #当前kafka对外提供服务的端口默认是9092
host.name=192.168.10.10 #这个参数默认是关闭的，在0.8.1有个bug，DNS解析问题，失败率的问题。
num.network.threads=3 #这个是borker进行网络处理的线程数
num.io.threads=8 #这个是borker进行I/O处理的线程数
log.dirs=/opt/kafka/kafkalogs/ #消息存放的目录，这个目录可以配置为“，”逗号分割的表达式，上面的num.io.threads要大于这个目录的个数这个目录，如果配置多个目录，新创建的topic他把消息持久化的地方是，当前以逗号分割的目录中，那个分区数最少就放那一个
socket.send.buffer.bytes=102400 #发送缓冲区buffer大小，数据不是一下子就发送的，先回存储到缓冲区了到达一定的大小后在发送，能提高性能
socket.receive.buffer.bytes=102400 #kafka接收缓冲区大小，当数据到达一定大小后在序列化到磁盘
socket.request.max.bytes=104857600 #这个参数是向kafka请求消息或者向kafka发送消息的请请求的最大数，这个值不能超过java的堆栈大小
num.partitions=1 #默认的分区数，一个topic默认1个分区数
log.retention.hours=168 #默认消息的最大持久化时间，168小时，7天
message.max.byte=5242880  #消息保存的最大值5M
default.replication.factor=2  #kafka保存消息的副本数，如果一个副本失效了，另一个还可以继续提供服务
replica.fetch.max.bytes=5242880  #取消息的最大直接数
log.segment.bytes=1073741824 #这个参数是：因为kafka的消息是以追加的形式落地到文件，当超过这个值的时候，kafka会新起一个文件
log.retention.check.interval.ms=300000 #每隔300000毫秒去检查上面配置的log失效时间（log.retention.hours=168 ），到目录查看是否有过期的消息如果有，删除
log.cleaner.enable=false #是否启用log压缩，一般不用启用，启用的话可以提高性能
zookeeper.connect=192.168.10.10:2181,192.168.10.11:2181,192.168.10.12:218 #设置zookeeper的连接端口
```

<span style='color:red'>2.kafa基本命令使用,1创建，2生产，3消费，4查看，5状态</span>

```
#集群任意节点创建topic都ok
./kafka-topics.sh --create --zookeeper python0:2181,python1:2181,python2:2181 --replication-factor 2 --partitions 1 --topic test
--replication-factor 2  #复制两份
--partitions 1          #创建1个分区
--topic                 #主题为test
```

````
./kafka-console-producer.sh --broker-list localhost:9092 --topic test
````

```
./kafka-console-consumer.sh --zookeeper python0:2181,python1:2181,python2:2181 --topic test --from-beginning
```

```
./kafka-topics.sh --list --zookeeper python0:2181,python1:2181,python2:2181
```

```
/kafka-topics.sh --describe --zookeeper python0:2181,python1:2181,python2:2181 --topic test
---
第一行给出了所有分区信息的摘要，接下来的每一行则给出具体的每一个分区信息
---
“leader”节点
“leader”节点负责响应给定节点的所有读写操作。每个节点都可能成为所有分区中一个随机选择分区的leader。
“replicas”是复制当前分区的节点列表，无论这些节点是不是leader、是不是可用。
“isr”是目前处于同步状态的replicas集合。它是replicas列表的子集，其中仅包含当前可用并且与leader同步的节点。
注意上述例子中，编号为1的节点是这个只有一个分区的主题的leader。
```

