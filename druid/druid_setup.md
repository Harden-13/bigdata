##### reference

http://druid.io/downloads.html

http://druid.io/docs/0.14.0-incubating/operations/other-hadoop.html

http://central.maven.org/maven2/mysql/mysql-connector-java/8.0.11/mysql-connector-java-8.0.11.jar

##### basic env

```
mysql-->5.7
druid-->0.14
内存需要满足-XX:MaxDirectMemory >= numThreads*sizeBytes
The amount of direct memory needed by Druid is at least，druid.processing.buffer.sizeBytes * (druid.processing.numMergeBuffers + druid.processing.numThreads + 1). You can ensure at least this amount of direct memory is available by providing -XX:MaxDirectMemorySize=<VALUE> at the command line.
```

| node1              | node2                | node3         |
| ------------------ | -------------------- | ------------- |
| overlord : 8090    | historical :8083     | broker : 8082 |
| coordinator : 8081 | middlemanager : 8091 | router : 8888 |

| 配置描述 | 文件路径                                     | 事项                                                         |
| -------- | -------------------------------------------- | ------------------------------------------------------------ |
| 公共配置 | conf/druid/_common/common.runtime.properties | 1.需要添加一些扩展信息extensions，2.需要配置Zookeeper集群信息，3.需要修改Metadata，4.需要修改Deep storage,hdfs,s3 |
|          |                                              |                                                              |

##### _common

1._common/common.runtime.properties

```
#extensions
druid.extensions.directory=/usr/local/druid-0.14/extensions/
druid.extensions.loadList=["druid-kafka-eight", "druid-histogram", "druid-datasketches", "druid-lookups-cached-global", "mysql-metadata-storage", "druid-hdfs-storage"]
#logging
druid.startup.logging.logProperties=true
#zookeeper
druid.zk.service.host=10.10.103.45,10.10.103.46,10.10.103.47
druid.zk.paths.base=/druid
druid.discovery.curator.path=/druid/test/discovery
#metadata
druid.metadata.storage.type=mysql
druid.metadata.storage.connector.connectURI=jdbc:mysql://10.10.103.225:3306/druid
druid.metadata.storage.connector.user=druid_w
druid.metadata.storage.connector.password=druid_w
#deep storage
druid.storage.type=hdfs
druid.storage.storageDirectory=/druid/segments
#indexing service logs
druid.indexer.logs.type=file
druid.indexer.logs.directory=/usr/local/druid-0.14/var/druid/indexing-logs
#service discovery
druid.selectors.indexing.serviceName=druid/overlord
druid.selectors.coordinator.serviceName=druid/coordinator
#monitoring
druid.monitoring.monitors=["org.apache.druid.java.util.metrics.JvmMonitor"]
druid.emitter=logging
druid.emitter.logging.logLevel=info
#storage type of double columns
druid.indexing.doubleStorage=double
#sql
druid.sql.enable=true
```

2.hadoop配置文件的依赖

```
cp /etc/hadoop/conf/*.xml /usr/local/druid-0.14/conf/druid/_common
```

#### node1

1.overlord's jvm.config

```
-server
-Xms3g
-Xmx3g
-XX:+ExitOnOutOfMemoryError
-Duser.timezone=UTC
-Dfile.encoding=UTF-8
-Djava.io.tmpdir=var/tmp
-Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager
```

2.overlord'sruntime.properties

```
druid.service=druid/overlord
druid.plaintextPort=8090
druid.indexer.queue.startDelay=PT30S
druid.indexer.runner.type=remote
druid.indexer.storage.type=metadata
```

3.coordinator jvm.config

```
-server
-Xms3g
-Xmx3g
-XX:+ExitOnOutOfMemoryError
-Duser.timezone=UTC
-Dfile.encoding=UTF-8
-Djava.io.tmpdir=var/tmp
-Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager
-Dderby.stream.error.file=/usr/local/druid-0.14/var/druid/derby.log
```

4.coordinator's runtime

```
druid.service=druid/coordinator
druid.plaintextPort=8081
druid.coordinator.startDelay=PT30S
druid.coordinator.period=PT30S
```

#### node2 

1.historical's jvm.config

```
-server
-Xms4g
-Xmx4g
-XX:MaxDirectMemorySize=2048m
-XX:+UseConcMarkSweepGC
-XX:+PrintGCDetails
-XX:+PrintGCTimeStamps
-Duser.timezone=Asia/Shanghai
-Dfile.encoding=UTF-8
-Djava.io.tmpdir=/usr/local/druid-0.14/var/tmp
-Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager
```

2.historical's runtime

```
druid.service=druid/historical
#druid.plaintextPort=8083
druid.port=8083
# HTTP server threads
druid.server.http.numThreads=25
# Processing threads and buffers
druid.processing.buffer.sizeBytes=536870912
druid.processing.numThreads=1
# Segment storage
druid.segmentCache.locations=[{"path":"/usr/local/druid-0.14/segment-cache","maxSize":130000000000}]
druid.server.maxSize=130000000000
# Query cache
#druid.historical.cache.useCache=true
#druid.historical.cache.populateCache=true
#druid.cache.type=caffeine
#druid.cache.sizeInBytes=2000000000

```

3.middlemanager's jvm.config

```
-server
-Xms64m
-Xmx64m
-XX:+UseConcMarkSweepGC
-XX:+PrintGCDetails
-XX:+PrintGCTimeStamps
-Duser.timezone=Asia/Shanghai
-Dfile.encoding=UTF-8
-Djava.io.tmpdir=/usr/local/druid-0.14/var/tmp
-Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager
```

4.middlemanager's runtime

```
druid.service=druid/middleManager
druid.plaintextPort=8091

# Number of tasks per middleManager
druid.worker.capacity=3

# Task launch parameters
druid.indexer.runner.javaOpts=-server -Xmx2g -Duser.timezone=UTC -Dfile.encoding=UTF-8 -XX:+ExitOnOutOfMemoryError -Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager
druid.indexer.task.baseTaskDir=/usr/local/druid-0.14/var/druid/task

# HTTP server threads
druid.server.http.numThreads=25

# Processing threads and buffers on Peons
druid.indexer.fork.property.druid.processing.buffer.sizeBytes=536870912
druid.indexer.fork.property.druid.processing.numThreads=2

# Hadoop indexing
druid.indexer.task.hadoopWorkingPath=/usr/local/druid-0.14/var/druid/hadoop-tmp
druid.indexer.task.defaultHadoopCoordinates=["org.apache.hadoop:hadoop-client:2.6.0-cdh5.9.0"]

# Peon properties
druid.indexer.fork.property.druid.monitoring.monitors=["com.metamx.metrics.JvmMonitor"]
druid.indexer.fork.property.druid.processing.buffer.sizeBytes=536870912
druid.indexer.fork.property.druid.processing.numThreads=2
druid.indexer.fork.property.druid.segmentCache.locations=[{"path": "/usr/local/druid-0.14/var/persistent/zk_druid", "maxSize": 0}]
druid.indexer.fork.property.druid.server.http.numThreads=20
```

#### node3

1.broker's jvm.config

```
-server
-Xms3g
-Xmx3g
-XX:+UseConcMarkSweepGC
-XX:+PrintGCDetails
-XX:+PrintGCTimeStamps
-XX:MaxDirectMemorySize=2048m
-Duser.timezone=Asia/Shanghai
-Dfile.encoding=UTF-8
-Djava.io.tmpdir=/user/locdruid-0.14/var/tmp
-Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager
```

2.runtime's runtime

```
druid.service=druid/broker
druid.plaintextPort=8082

# HTTP server settings
druid.server.http.numThreads=60
# HTTP client settings
druid.broker.http.numConnections=10

# Processing threads and buffers
druid.processing.buffer.sizeBytes=536870912
druid.processing.numMergeBuffers=2
druid.processing.numThreads=1

# Query cache disabled -- push down caching and merging instead
#druid.broker.cache.useCache=false
#druid.broker.cache.populateCache=false
druid.broker.cache.useCache=true
druid.broker.cache.populateCache=true
druid.cache.type=local
druid.cache.sizeInBytes=1073741824

```

#### node.sh shell 添加一下内容 

```
DRUID_CONF_DIR=/usr/local/druid-0.14/conf/druid
HADOOP_CONF_DIR=/etc/hadoop/conf
DRUID_LIB_DIR=/usr/local/druid-0.14/lib/
DRUID_LOG_DIR=/usr/local/druid-0.14/log
DRUID_PID_DIR=/usr/local/druid-0.14/var/druid/pids
```

#### launch

```
/usr/local/druid-0.14/bin/node.sh historical start
/usr/local/druid-0.14/bin/node.sh borker start
/usr/local/druid-0.14/bin/node.sh coordinator  start
/usr/local/druid-0.14/bin/node.sh overlord start
/usr/local/druid-0.14/bin/node.sh middleManager start
```

#### url

```
http://10.10.103.45:8081/index.html#/
http://10.10.103.45:8090/console.html
```



