#### kafka message design

##### 1.v1格式      备注：0.11之前是v1,0.11之后是v2

```
kafka消息层次分为2曾：
1.消息集合(message set):包含若干条日志项，每个日志项封装了消息以及元数据
2.消息(message)
```

```
下面我们来说说消息集合日志项的计算,消息集合中得每一项得格式如下图所示：
```

![](https://github.com/Harden-13/bigdata/blob/master/images/v1_log_head.png)

```
每个消息集合中的日志项由日志项头部+一条“浅层”消息构成。
浅层(shallow)消息：如果是未压缩消息，shallow消息就是消息本身；如果是压缩消息，Kafka会将多条消息压缩再一起封装进这条浅层消息的value字段。这条浅层消息也被称为wrapper消息，里面包含的消息被称为内部消息，即inner message。由此可见，老版本的message batch中通常都只包含一条消息，即使是对于已压缩消息而言，它也只是包含一条shallow消息。
日志项头部(log entry header)：8字节的offset字段 + 4个字节的size字段，共计12个字节。其中offset保存的是这条消息的位移。对于未压缩消息，它就是消息的位移；如果是压缩消息，它表示wrapper消息中最后一条inner消息的位移。由此可见，给定一个老版本的消息集合倘若要寻找该消息集合的起始位移(base offset或starting offset)是一件很困难的事情，因为这通常都需要深度遍历整个inner消息，这也就是意味着broker端需要执行解压缩的操作，因此代价非常高。
```



```
v1消息格式：
此版本的消息头部开销等于4 + 1 + 1 + 8 + 4 + 4 = 22字节，也就是说一条Kafka消息长度再小，也不可以小于22字节，否则会被Kafka视为corrupted。我们能够很容易地计算每条Kafka消息的总长度。注意，这里我们讨论的未压缩消息。已压缩消息的计算会复杂一些，故暂且不讨论。
假设有一条Kafka消息，key是“key”，value是“hello”，那么key的长度就是3，value的长度就是5，因此这条Kafka消息需要占用22 + 3 + 5 = 30字节；倘若另一条Kafka消息未指定key，而value依然是“hello”，那么Kafka会往key长度字段中写入-1表明key是空，因而不再需要保存key信息，故总的消息长度= 22 + 5 = 27字节
总之单条Kafka消息长度的计算是很简单的
```

![](https://github.com/Harden-13/bigdata/blob/master/images/v1_message_type.png)

```
我们来看下如何计算消息集合大小，还是拿之前的两条Kafka消息为例。第一条消息被封装进一个消息集合，那么该消息集合总的长度 = 12 + 30 = 42字节，而包含第二条未指定key消息的消息集合总长度 = 12 + 27 = 39字节。
```

##### 2.v2格式

```
v2版本的消息格式比起v1有很大的变化。除了可变长度这一点，v2版本的属性字段被弃用了，CRC被移除了，另外增加了消息总长度、时间戳增量(timestamp delta)、位移增量(offset delta)和headers信息。我们分别说下：

1.消息总长度：直接计算出消息的总长度并保存在第一个字段中，而不需要像v1版本时每次需要重新计算。这样做的好	处在于提升解序列化的效率——拿到总长度后，Kafka可以直接new出一个等长度的ByteBuffer，然后装填各个字     段。同时有了这个总长度，在遍历消息时可以实现快速地跳跃，省去了很多copy的工作。
2.时间戳增量：消息时间戳与所属record batch起始时间戳的差值，保存差值可以进一步节省消息字节数
3.位移增量：消息位移与所属record batch起始位移的差值，保存差值可以进一步节省消息字节数
4.headers：这和本文之前提到的所有header都无关。这是0.11版本引入的新字段。它是一个数组，里面的Header   只有两个字段：key和value，分别是String和byte[]类型。
5.v2版本不在对每条消息执行CRC校验，而是针对整个batch
6.v2版本不在使用属性字节，原先保存在属性字段中的诸如压缩类型、时间戳类型等信息都统一保存在外层的batch中
```

![](C:\Users\lenovo\Desktop\bigdata\bigdata\images\v2_message_type.png)

