## 1.kafka producer

### 1.消息发送流程

```
Kafka的Producer发送消息采用的是异步发送的方式。在消息发送的过程中，涉及到了两个线程——main线程和Sender线程，以及一个线程共享变量——RecordAccumulator。main线程将消息发送给RecordAccumulator，Sender线程不断从RecordAccumulator中拉取消息发送到Kafka broker。
```

* 相关参数

```
batch.size：只有数据积累到batch.size之后，sender才会发送数据。
linger.ms：如果数据迟迟未达到batch.size，sender等待linger.time之后就会发送数据。
```

#### 1.java代码

##### 1.异步调用api(没有回调函数)

```
KafkaProducer：需要创建一个生产者对象，用来发送数据
ProducerConfig：获取所需的一系列配置参数
ProducerRecord：每条数据都要封装成一个ProducerRecord对象
```

```
public class CustomProducer {
    public static void main(String[] args)  {
        Properties props = new Properties();
        props.put("bootstrap.servers", "hadoop0:9092");//kafka集群，broker-list
        props.put("acks", "all");
        props.put("retries", 1);//重试次数
        props.put("batch.size", 16384);//批次大小
        props.put("linger.ms", 1);//等待时间
        props.put("buffer.memory", 33554432);//RecordAccumulator缓冲区大小
        props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

        Producer<String, String> producer = new KafkaProducer<>(props);
        for (int i = 0; i < 50000; i++) {
            producer.send(new ProducerRecord<String, String>("first", "hello"+i, "hello"+i));
        }
        producer.close();
    }
}
```

##### 2.异步调用api(有回调函数)

* new Callback() 

```
回调函数会在producer收到ack时调用，为异步调用，该方法有两个参数，分别是RecordMetadata和Exception，如果Exception为null，说明消息发送成功，如果Exception不为null，说明消息发送失败。
注意：消息发送失败会自动重试，不需要我们在回调函数中手动重试。
```

* java代码

```

public class CustomProducer {
    public static void main(String[] args) throws ExecutionException, InterruptedException {
        //1. new对象
        Properties config = new Properties();
        config.setProperty("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        config.setProperty("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        config.setProperty("acks", "all");
        config.setProperty("bootstrap.servers", "hadoop102:9092, hadoop103:9092, hadoop104:9092");
        config.setProperty("batch.size", "16384");
        config.setProperty("linger.ms", "1");
        config.setProperty("enable.idempotence", "true");
        KafkaProducer<String, String> kafkaProducer = new KafkaProducer<>(config);

        //2. 操作集群
        for (int i = 0; i < 100; i++) {
            Future<RecordMetadata> future = kafkaProducer.send(
                    new ProducerRecord<String, String>(
                            "first",
                            Integer.toString(i),
                            "Hello + " + i
                    ),
                    new Callback() {
                        @Override
                        public void onCompletion(RecordMetadata metadata, Exception exception) {
                            if (metadata != null) {
                                System.out.println("发送成功！发到了" +
                                        metadata.topic() +
                                        "话题的" +
                                        metadata.partition() +
                                        "分区的第" +
                                        metadata.offset() +
                                        "条消息");
                            }
                        }
                    }
            );
            System.out.println("已发送第" + i + "条！");
            System.out.println(future.isDone());
        }

        //3. 关闭资源
        kafkaProducer.close();
    }
}
```

消费500行



### 2.kafka consumer

#### 1.消费流程

* offset

```
Consumer消费数据时的可靠性是很容易保证的，因为数据在Kafka中是持久化的，故不用担心数据丢失问题。
由于consumer在消费过程中可能会出现断电宕机等故障，consumer恢复后，需要从故障前的位置的继续消费，所以consumer需要实时记录自己消费到了哪个offset，以便故障恢复后继续消费。
所以offset的维护是Consumer消费数据是必须考虑的问题

```

#### 2.java代码

##### 1.自动提交

* 用到的类

```
KafkaConsumer：需要创建一个消费者对象，用来消费数据
ConsumerConfig：获取所需的一系列配置参数
ConsuemrRecord：每条数据都要封装成一个ConsumerRecord对象
```

* 用到的参数

```
enable.auto.commit：是否开启自动提交offset功能
auto.commit.interval.ms：自动提交offset的时间间隔
```

* java代码

```
public class CustomConsumer {
    public static void main(String[] args) {
        //1. new对象
        Properties config = new Properties();
        config.setProperty("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
        config.setProperty("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
        config.setProperty("bootstrap.servers", "hadoop102:9092, hadoop103:9092, hadoop104:9092");
        config.setProperty("group.id", "testAPI");
        config.setProperty("auto.offset.reset", "earliest");
        config.setProperty("enable.auto.commit", "true");
        config.setProperty("auto.commit.interval.ms", "5000");
        KafkaConsumer<String, String> kafkaConsumer = new KafkaConsumer<>(config);

        //2. 消费
        kafkaConsumer.subscribe(Collections.singleton("first"));
		//没有while循环，每500(默认的参数控制)条数据poll一次，并且记录下offset,
        while (true) {
            ConsumerRecords<String, String> records = kafkaConsumer.poll(Duration.ofSeconds(10));

            //消费拉到的消息
            for (ConsumerRecord<String, String> record : records) {
                System.out.println(record);
            }
        }
        //3. 关闭
//        kafkaConsumer.close();
    }
}
```

##### 2.手动提交

* 方式

```
手动提交offset的方法有两种：
分别是commitSync（同步提交）和commitAsync（异步提交）。两者的相同点是，都会将本次poll的一批数据最高的偏移量提交；不同点是，commitSync阻塞当前线程，一直到提交成功，并且会自动失败重试（由不可控因素导致，也会出现提交失败）；而commitAsync则没有失败重试机制，故有可能提交失败。
```

* 异步手动提交

```
步提交offset更可靠一些，但是由于其会阻塞当前线程，直到提交成功。因此吞吐量会收到很大的影响。因此更多的情况下，会选用异步提交offset的方式
```

* 异步手动提交代码

```
public class CustomConsumerManual {
    public static void main(String[] args) {
        //1. new对象
        Properties config = new Properties();
        config.setProperty("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
        config.setProperty("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
        config.setProperty("bootstrap.servers", "hadoop102:9092, hadoop103:9092, hadoop104:9092");
        config.setProperty("group.id", "testAPI222");
        config.setProperty("auto.offset.reset", "earliest");
        config.setProperty("enable.auto.commit", "false");
//        config.setProperty("auto.commit.interval.ms", "5000");
        KafkaConsumer<String, String> kafkaConsumer = new KafkaConsumer<>(config);

        //2. 消费
        kafkaConsumer.subscribe(Collections.singleton("first"));

        while (true) {
            ConsumerRecords<String, String> records = kafkaConsumer.poll(Duration.ofSeconds(10));
            //引出漏数据
			// kafkaConsumer.commitAsync(new OffsetCommitCallback()
            //消费拉到的消息
            for (ConsumerRecord<String, String> record : records) {
                System.out.println(record);
            }
            //可能引发重复数据
            kafkaConsumer.commitAsync(new OffsetCommitCallback() {
                @Override
                public void onComplete(Map<TopicPartition, OffsetAndMetadata> offsets, Exception exception) {
                    if (exception == null) {
                        offsets.forEach(((topicPartition, offsetAndMetadata) -> {
                            System.out.println(topicPartition);
                            System.out.println(offsetAndMetadata);
                        }));
                    }
                }
            });
        }
        //3. 关闭
//        kafkaConsumer.close();
    }
}
```

* commit提交位置引发的问题

```
数据漏消费和重复消费分析
无论是同步提交还是异步提交offset，都有可能会造成数据的漏消费或者重复消费。先提交offset后消费，有可能造成数据的漏消费；而先消费后提交offset，有可能会造成数据的重复消费。

```

