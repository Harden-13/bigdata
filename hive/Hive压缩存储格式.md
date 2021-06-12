### Hive压缩存储格式

#### 1.压缩

##### 1.MR支持编码

| 压缩格式         | 算法    | 文件扩展名 | 是否可切分 |
| ---------------- | ------- | ---------- | ---------- |
| DEFLATE          | DEFLATE | .deflate   | 否         |
| Gzip             | DEFLATE | .gz        | 否         |
| bzip2            | bzip2   | .bz2       | 是         |
| LZO(过时)        | LZO     | .lzo       | 是         |
| Snappy(用的最多) | Snappy  | .snappy    | 否         |
| zstd(潮流)       |         |            |            |

##### 2.编码解码器

| 压缩格式 | 对应的编码/解码器                          |
| -------- | ------------------------------------------ |
| DEFLATE  | org.apache.hadoop.io.compress.DefaultCodec |
| gzip     | org.apache.hadoop.io.compress.GzipCodec    |
| bzip2    | org.apache.hadoop.io.compress.BZip2Codec   |
| LZO      | com.hadoop.compression.lzo.LzopCodec       |
| Snappy   | org.apache.hadoop.io.compress.SnappyCodec  |

##### 3.性能对比

| 压缩算法 | 原始文件大小 | 压缩文件大小 | 压缩速度 | 解压速度 |
| -------- | ------------ | ------------ | -------- | -------- |
| gzip     | 8.3GB        | 1.8GB        | 17.5MB/s | 58MB/s   |
| bzip2    | 8.3GB        | 1.1GB        | 2.4MB/s  | 9.5MB/s  |
| LZO      | 8.3GB        | 2.9GB        | 49.3MB/s | 74.6MB/s |

##### 4.参数配置（mapred-site.xml文件中）

| 参数                                                 | 默认值                                                       | 阶段        | 建议                                         |
| ---------------------------------------------------- | ------------------------------------------------------------ | ----------- | -------------------------------------------- |
| io.compression.codecs      （在core-site.xml中配置） | org.apache.hadoop.io.compress.DefaultCodec,   org.apache.hadoop.io.compress.GzipCodec,   org.apache.hadoop.io.compress.BZip2Codec,   org.apache.hadoop.io.compress.Lz4Codec | 输入压缩    | Hadoop使用文件扩展名判断是否支持某种编解码器 |
| mapreduce.map.output.compress                        | false                                                        | mapper输出  | 这个参数设为true启用压缩                     |
| mapreduce.map.output.compress.codec                  | org.apache.hadoop.io.compress.DefaultCodec                   | mapper输出  | 使用LZO、LZ4或snappy编解码器在此阶段压缩数据 |
| mapreduce.output.fileoutputformat.compress           | false                                                        | reducer输出 | 这个参数设为true启用压缩                     |
| mapreduce.output.fileoutputformat.compress.codec     | org.apache.hadoop.io.compress. DefaultCodec                  | reducer输出 | 使用标准工具或者编解码器，如gzip和bzip2      |
| mapreduce.output.fileoutputformat.compress.type      | RECORD                                                       | reducer输出 | SequenceFile输出使用的压缩类型：NONE和BLOCK  |

#### 2.输出压缩

##### 1.map输出压缩

* map输出阶段压缩可以减少job中map和Reduce task间数据传输量

```
//开启hive中间传输数据压缩功能
set hive.exec.compress.intermediate=true;
//开启mapreduce中map输出压缩功能
set mapreduce.map.output.compress=true;
//设置mapreduce中map输出数据的压缩方式
set mapreduce.map.output.compress.codec=org.apache.hadoop.io.compress.SnappyCodec;
//执行查询语句
select count(ename) name from emp;
```

##### 2.reduce输出压缩

* Hive将输出写入到表中时，输出内容同样可以进行压缩

```
//开启hive最终输出数据压缩功能
set hive.exec.compress.output=true;
//开启mapreduce最终输出数据压缩
set mapreduce.output.fileoutputformat.compress=true;
//设置mapreduce最终数据输出压缩方式
set mapreduce.output.fileoutputformat.compress.codec =
 org.apache.hadoop.io.compress.SnappyCodec;
//设置mapreduce最终数据输出压缩为块压缩
set mapreduce.output.fileoutputformat.compress.type=BLOCK;
//测试一下输出结果是否是压缩文件
insert overwrite local directory
 '/opt/module/hive/datas/distribute-result' select * from emp distribute by deptno sort by empno desc;

```

### 文件存储格式

#### 1.存储格式

```
TEXTFILE 、SEQUENCEFILE、ORC、PARQUET
```

#### 2.存储特点

```
TEXTFILE和SEQUENCEFILE的存储格式都是基于行存储的；
```

```
ORC和PARQUET是基于列式存储的
```

#### 3.介绍各个存储格式

##### 1.TextFile

* TextFile格式

```
默认格式，数据不做压缩，磁盘开销大，数据解析开销大。可结合Gzip、Bzip2使用，但使用Gzip这种方式，hive不会对数据进行切分，从而无法对数据进行并行操作
```

##### 2.orc

* orc格式

```
每个Orc文件由1个或多个stripe组成，每个stripe一般为HDFS的块大小，每一个stripe包含多条记录，这些记录按照列进行独立存储，对应到Parquet中的row group的概念。每个Stripe里有三部分组成，分别是Index Data，Row Data，Stripe Footer：
```

* 原理解读

```
1）Index Data：一个轻量级的index，默认是每隔1W行做一个索引。这里做的索引应该只是记录某行的各字段在Row Data中的offset。
2）Row Data：存的是具体的数据，先取部分行，然后对这些行按列进行存储。对每个列进行了编码，分成多个Stream来存储。
3）Stripe Footer：存的是各个Stream的类型，长度等信息。
每个文件有一个File Footer，这里面存的是每个Stripe的行数，每个Column的数据类型信息等；每个文件的尾部是一个PostScript，这里面记录了整个文件的压缩类型以及FileFooter的长度信息等。在读取文件时，会seek到文件尾部读PostScript，从里面解析到File Footer长度，再读FileFooter，从里面解析到各个Stripe信息，再读各个Stripe，即从后往前读。

```

##### 3.parquet

* 原理

```
Parquet文件是以二进制方式存储的，所以是不可以直接读取的，文件中包括该文件的数据和元数据，因此Parquet格式文件是自解析的。
（1）行组(Row Group)：每一个行组包含一定的行数，在一个HDFS文件中至少存储一个行组，类似于orc的stripe的概念。
（2）列块(Column Chunk)：在一个行组中每一列保存在一个列块中，行组中的所有列连续的存储在这个行组文件中。一个列块中的值都是相同类型的，不同的列块可能使用不同的算法进行压缩。
（3）页(Page)：每一个列块划分为多个页，一个页是最小的编码的单位，在同一个列块的不同页可能使用不同的编码方式。
通常情况下，在存储Parquet数据的时候会按照Block大小设置行组的大小，由于一般情况下每一个Mapper任务处理数据的最小单位是一个Block，这样可以把每一个行组由一个Mapper任务处理，增大任务执行并行度。Parquet文件的格式。

```

#### 4.实验对比

##### 1.存储大小对比

* 存储占用结论

```
ORC(7.7) >  Parquet(13.1M) >  textFile（18M）
```

##### 2.查询测试速度

* 查询并写入本地文件

```
存储文件的查询速度总结：查询速度相近。
```

##### 3.压缩和存储结合结论

```
存储方式和压缩总结
在实际的项目开发当中，hive表的数据存储格式一般选择：orc或parquet。压缩方式一般选择snappy，lzo。

```

