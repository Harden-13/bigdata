## Kafka-to-Flume

### 1.kafka source

#### 1.kafka.consumer.group.**id**

* kafka消息组实验对比

```
# 配置文件a1
a1.sources.r1.kafka.consumer.group.id = flume
# 配置文件amut1
amutl1.sources.r1.kafka.consumer.group.id = flume
# 同时启动2个flume
flume-ng agent -c $FLUME_HOME/conf -f /opt/module/flume/job/kafka-to-flume/kafka-source-mutl.conf -n amutl1 -Dflume.root.logger=INFO,console

flume-ng agent -c $FLUME_HOME/conf -f /opt/module/flume/job/kafka-to-flume/kafka-source.conf -n a1 -Dflume.root.logger=INFO,console
# 启动一个kafka生产者
kafka-console-producer.sh --broker-list hadoop0:9092 --topic first
```

* 实验总结

```
相当于1个组内2个消费者消费topics.在一个单位时间内只有一个消费者消费数据，在水平方向拓展了消费数据的能力
```

