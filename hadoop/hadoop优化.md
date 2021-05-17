## hadoop

### 1.flume中hdfs-sink小文件

#### 1.小文件影响

* 元数据层面

```
每个小文件都有一份元数据，其中包括文件路径，文件名，所有者，所属组，权限，创建时间等，这些信息都保存在Namenode内存中。所以小文件过多，会占用Namenode服务器大量内存，影响Namenode性能和使用寿命
```

* 计算层面

```
默认情况下MR会对每个小文件启用一个Map任务计算，非常影响计算性能。同时也影响磁盘寻址时间
```

#### 2.小文件处理

* 参数处理

```
官方默认的这三个参数配置写入HDFS后会产生小文件，hdfs.rollInterval、hdfs.rollSize、hdfs.rollCount
```

* 参数含义

```

基于以上hdfs.rollInterval=3600，hdfs.rollSize=134217728，hdfs.rollCount =0几个参数综合作用，效果如下：
（1）文件在达到128M时会滚动生成新文件
（2）文件创建超3600秒时会滚动生成新文件

```

