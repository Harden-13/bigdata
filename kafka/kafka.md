### kafka 

#### 1.kafka基础架构

* 架构特点

```
一对多，消费者消费数据之后不会清除消息
```

* 架构组成

```
1、消费者：（Consumer）：从消息队列中请求消息的客户端应用程序
2、生产者：（Producer）  ：向broker发布消息的应用程序
3、（broker）：用来接收生产者发送的消息并将这些消息路由给服务器中的队列，便于kafka将生产者发送的消息，动态的添加到磁盘并给每一条消息一个偏移量，一台kafka服务器就是一个broker。一个集群由多个broker组成。一个broker可以容纳多个topic
4.主题（topic）：可以理解为一个队列，生产者和消费者面向的都是一个topic；
5.分区（partition）：分区是kafka消息队列组织的最小单位,一个Topic中的消息数据按照多个分区组织;每个partition是一个有序的队列；kafka分区是提高kafka性能的关键所在,增加分区，提高性能（1个topic的partition不受broker数量限制）
6.Consumer Group （CG）：消费者组，由多个consumer组成。消费者组内每个消费者负责消费不同分区的数据，一个分区只能由一个消费者消费；消费者组之间互不影响。所有的消费者都属于某个消费者组，即消费者组是逻辑上的一个订阅者（group的数量不能超过partition的数量，否则其中一个消费者无法获取数据）
7.副本：（Replica），为保证集群中的某个节点发生故障时，该节点上的partition数据不丢失，且kafka仍然能够继续工作，kafka提供了副本机制，一个topic的每个分区都有若干个副本，一个leader和若干个follower。（设置副本的数量不能超过broker的数量）
8.leader：每个分区多个副本的“主”，生产者发送数据的对象，以及消费者消费数据的对象都是leader。
9.follower：每个分区多个副本中的“从”，实时从leader中同步数据，保持和leader数据的同步。leader发生故障时，某个follower会成为新的leader。

备注：：：动态扩容通过zookeeper实现，kafka增加和减少服务器都会在Zookeeper节点上触发相应的事件kafka系统会捕获这些事件，进行新一轮的负载均衡，客户端也会捕获这些事件来进行新一轮的处理
```

#### 2.kafka集群搭建

##### 1.zookeeper setup

* <span style='color:red'>1.Kafka集群是把状态保存在Zookeeper中的，首先要搭建Zookeeper集群。</span>

```
参照zk的搭建文档
```

##### 2.kafka setup

* 预安装环境

```
1.kafka_2.11-2.4.1.tgz
2.zk版本3.5.7
3.3台机器，部署好一台(hadoop0)通过脚本分发到另外2台机器（hadoop1,hadoop2）
4.root用户启动
5.启动脚本命令
my_command.sh '/opt/module/kafka/bin/kafka-server-start.sh -daemon /opt/module/kafka/config/server.properties'
```

```
tar -xvf kafka_2.11-2.4.1.tgz -C /opt/module/
ln -s kafka_2.11-2.4.1 kafka
cd kafka && mkdir logs
```

*  server.properties配置文件

```
#broker的全局唯一编号，不能重复
broker.id=0
#删除topic功能使能
delete.topic.enable=true
#处理网络请求的线程数量
num.network.threads=3
#用来处理磁盘IO的现成数量
num.io.threads=8
#发送套接字的缓冲区大小
socket.send.buffer.bytes=102400
#接收套接字的缓冲区大小
socket.receive.buffer.bytes=102400
#请求套接字的缓冲区大小
socket.request.max.bytes=104857600
#kafka运行日志存放的路径
log.dirs=/opt/module/kafka/logs
#topic在当前broker上的分区个数
num.partitions=1
#用来恢复和清理data下数据的线程数量
num.recovery.threads.per.data.dir=1
#segment文件保留的最长时间，超时将被删除
log.retention.hours=168
#配置连接Zookeeper集群地址
zookeeper.connect=hadoop102:2181,hadoop103:2181,hadoop104:2181/kafka

```

* 环境变量

```
#KAFKA_HOME
export KAFKA_HOME=/opt/module/kafka
export PATH=$PATH:$KAFKA_HOME/bin
```

##### 3.配置文件详解

* <span style='color:red'>1.配置文件解析</span>

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
zookeeper.connect=192.168.10.10:2181,192.168.10.11:2181,192.168.10.12:2181 #设置zookeeper的连接端口
```

<span style='color:red'>2.kafa基本命令使用,1创建，2生产，3消费，4查看，5状态，6删除</span>

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

#### 3.commad

##### 1.查看

* 普通查看

```
kafka-topics.sh --zookeeper hadoop0:2181,hadoop1:2181,hadoop2:2181 --list
```

* 查看详情

```
kafka-topics.sh --zookeeper hadoop0:2181,hadoop1:2181,hadoop2:2181 --describe --topic first
```

##### 2.**创建topic**

```
kafka-topics.sh --zookeeper  hadoop0:2181,hadoop1:2181,hadoop2:2181  --create --replication-factor 3 --partitions 4 --topic first
```

* 选项说明

```
--topic 定义topic名
--replication-factor  定义副本数
--partitions  定义分区数
```

##### 3.删除

```
kafka-topics.sh --bootstrap-server hadoop0:9092 --delete --topic first
需要server.properties中设置delete.topic.enable=true否则只是标记删除。

```

##### 4.发送消息

```
kafka-console-producer.sh --broker-list hadoop0:9092 --topic first

```

##### 5.消费消息

* hadoop1  （--from-beginning：会把主题中以往所有的数据都读取出来。）

```
kafka-console-consumer.sh --bootstrap-server hadoop0:9092 --from-beginning --topic first
```

* hadoop2 （--from-beginning：会把主题中以往所有的数据都读取出来。）

```
kafka-console-consumer.sh --bootstrap-server hadoop0:9092 --from-beginning --topic first
```

* 组消费（每个组的数量不能超过分区数量）

```
# 3个组成员，1台机器3个xshell执行
kafka-console-consumer.sh --bootstrap-server hadoop1:9092 --from-beginning --group 0 --topic first
#通过4中的命令 发送信息，窗口1接受一部分数据，窗口2接受一部分数据
#同一个消费者组中的消费者，同一时刻只能有一个消费者消费。由于一个消费者处理四个生产者发送到分区的消息，压力有些大，需要帮手来帮忙分担任务。我们可以通过增加消费组的消费者来进行水平扩展提升消费能力
```

##### 6.修改分区个数

* 只能修改个数是大于之前的

```
kafka-topics.sh --bootstrap-server hadoop0:2181 --alter --topic first --partitions 6
```

#####  7.参数区别

* --zookeeper --broker-list --bootstrap-server

```
broker-list指定集群中的一个或者多个服务器，一般我们再使用console-producer的时候，这个参数是必备参数
```

```
--zookeeper：老版本的用法，0.8以前的kafka，消费的进度(offset)是写在zk中的，所以consumer需要知道zk的地址。对应2181端口
--bootstrap-server：后来的版本都统一由broker管理，所以就用bootstrap-server了。对应9092端口
```



#### 4.kafka信息在zookeeper

##### 1.谁是kafka的控制节点

* hadoop0的时间戳最小，当选controller,争抢机制，谁先注册谁就是controller

```
get /controller
{"version":1,"brokerid":0,"timestamp":"1620732280197"}

get /brokers/ids/0
{"listener_security_protocol_map":{"PLAINTEXT":"PLAINTEXT"},"endpoints":["PLAINTEXT://hadoop0:9092"],"jmx_port":-1,"host":"hadoop0","timestamp":"1620732279919","port":9092,"version":4}
get /brokers/ids/1
{"listener_security_protocol_map":{"PLAINTEXT":"PLAINTEXT"},"endpoints":["PLAINTEXT://hadoop1:9092"],"jmx_port":-1,"host":"hadoop1","timestamp":"1620732281976","port":9092,"version":4}
get /brokers/ids/2
{"listener_security_protocol_map":{"PLAINTEXT":"PLAINTEXT"},"endpoints":["PLAINTEXT://hadoop2:9092"],"jmx_port":-1,"host":"hadoop2","timestamp":"1620732283498","port":9092,"version":4}

```



#### 5.kafka manager

```
http://ip:9090 //需要安装 kafka manager
```

