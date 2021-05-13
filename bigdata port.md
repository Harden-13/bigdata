##### hadoop3.x常见端口

```
hdfs namenode				9820
hdfs namenode http ui		9870
sencondary namenode			9869
sencondary namenode http ui	9868
hdfs datanode				9866
hdfs datanode ipc			9867
hdfs datanode http ui		9864
yarn rescouceManager		8088
yarn server jobhistory		10020
yarn web jobhistory			19888
```

##### hadoop ha port

```
ResourceManager	:	8033,8088
NodeManager		:	8040,8042
namenoderpc		:	8020/9870(web)
datanode		:	9864,9866,9867
journalnode 	:	8485,8480
zkfs			:	8019
```

##### zookeeper

```
client connect			:	2181
zkcluster innerconnect	:	2888
zk vote					:	3888
```

##### hive 

```
metastore server	:	9083
hive jdbc			:	10000
```

##### kafka

```
kafka cluster connect	:	9092
```

##### hue

```
hue webui	:	8888
```

##### spark

```
master connect work & commit application	:	7077
master webui	:	8080
work webui		:	8081
driver webui	:	4040
spark history server web ui	:	18080
```

