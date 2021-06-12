## <span style='color:yellow'>优化策略</span>

### <span style='color:red'>1.压缩</span>

#### 1.mapreduce阶段

* 压缩场景

```
通过对mapper，reduce运行过程数据进行压缩，以减少磁盘io，提高mr程序运行速度
```

* 压缩原则

```
运算密集型的job，少用压缩
io密集型的job，多用压缩
```

* 压缩编码

| 压缩格式 | hadoop自带？ | 算法    | 文件扩展名 | 是否可切分 | 换成压缩格式后，原来的程序是否需要修改 |
| -------- | ------------ | ------- | ---------- | ---------- | -------------------------------------- |
| DEFLATE  | 是，直接使用 | DEFLATE | .deflate   | 否         | 和文本处理一样，不需要修改             |
| Gzip     | 是，直接使用 | DEFLATE | .gz        | 否         | 和文本处理一样，不需要修改             |
| bzip2    | 是，直接使用 | bzip2   | .bz2       | 是         | 和文本处理一样，不需要修改             |
| LZO      | 否，需要安装 | LZO     | .lzo       | 是         | 需要建索引，还需要指定输入格式         |
| Snappy   | 是，直接使用 | Snappy  | .snappy    | 否         | 和文本处理一样，不需要修改             |

* 性能对比

| 压缩算法 | 原始文件大小 | 压缩文件大小 | 压缩速度 | 解压速度 |
| -------- | ------------ | ------------ | -------- | -------- |
| gzip     | 8.3GB        | 1.8GB        | 17.5MB/s | 58MB/s   |
| bzip2    | 8.3GB        | 1.1GB        | 2.4MB/s  | 9.5MB/s  |
| LZO      | 8.3GB        | 2.9GB        | 49.3MB/s | 74.6MB/s |

* 实验例子

```
//block信息里面会显示block0,block1,block2,block3
dd if=/dev/zero of=test bs=1M count=500
hadoop fs -put test hdfs://hadoop0:8020/
	hadoop	supergroup	500 MB	May 11 16:31	3	128 MB	test(block0,1,2,3)
```

```
从上述中明显（500M）可以看到：gzip格式的数据，不支持切分的真正含义，并不是说HDFS不会将文件分布式的存储在各个节点，而是在计算的时候，不支持切分，也就是仅仅有一个split，从而也就是仅有一个map，这样的效率是及其低下的。
```

#### 2.lzo压缩（已过时）

* 编译lzo

```
参考hadoop_lzo.txt
```

* 配置步骤（分发hadoop0,1,2）

```
/opt/module/hadoop/share/hadoop/common/hadoop-lzo-0.4.20.jar（编译好的lzo）
<!-- vim core-site.xml-->
<configuration>
    <property>
        <name>io.compression.codecs</name>
        <value>
            org.apache.hadoop.io.compress.GzipCodec,
            org.apache.hadoop.io.compress.DefaultCodec,
            org.apache.hadoop.io.compress.BZip2Codec,
            org.apache.hadoop.io.compress.SnappyCodec,
            com.hadoop.compression.lzo.LzoCodec,
            com.hadoop.compression.lzo.LzopCodec
        </value>
    </property>
    <property>
        <name>io.compression.codec.lzo.class</name>
        <value>com.hadoop.compression.lzo.LzoCodec</value>
    </property>
</configuration>
```

* 上传文件测试

```
hadoop fs -put bigtable.lzo /input
# 为lzo文件创建索引，否则还是一个map程序
hadoop jar /opt/module/hadoop/share/hadoop/common/hadoop-lzo-0.4.20.jar  com.hadoop.compression.lzo.DistributedLzoIndexer /input/bigtable.lzo
#执行测试mr
hadoop jar /opt/module/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.1.3.jar wordcount -Dmapreduce.job.inputformat.class=com.hadoop.mapreduce.LzoTextInputFormat /input /output1
```

#### 3.snappy

#### 4.zstd(目前hadoop有bug)

