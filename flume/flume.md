##### overall

```
flume传递数据，包含三个组件：source，channel，sink.
webserver-->agent(source->channel->sink)-->hdfs
channel保证了一旦数据源过快，sink来不及消费保存数据造成数据丢失
```

##### example ：本地日志文件打到kafka

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
agent.sinks.loggerSink.kafka.producer.compression.type = snappy
```

```
###exec example 1
agent.sources.seqGenSrc.type = exec
agent.sources.seqGenSrc.shell = /bin/bash -c
agent.sources.seqGenSrc.command = for i in /path/*.txt; do cat $i; done
#agent.sources.seqGenSrc.command = tail -F /data/logs/infoserver/`date +%Y%m%d`.log

###eexec example 2
从不断追加的日志文件录入flume
agent.sources.seqGenSrc.type = exec
agent.sources.seqGenSrc.command = tail -F /data/logs/infoserver/access.log
```

```

```

