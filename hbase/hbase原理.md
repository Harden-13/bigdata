# <span style="color:red">hbase</span>

## <span style="color:yellow" >regionserver</span>

### 1.架构图

![regionserver](C:\Users\lenovo\Desktop\bigdata\hbase\regionserver.png)

| 架构              |                                                              |
| ----------------- | ------------------------------------------------------------ |
| **Region Server** | 每regionserver可以服务多个Region；每regionserver有多个store,1个wal，1个blockcache |
| **Block **Cache   | 读缓存，每次查询出的数据会缓存在BlockCache中，方便下次查询。 |
| **WAL**           | 数据要经MemStore排序后才能刷写到HFile，为了避免数据在内存中会丢失，数据会先写入叫Write-Ahead logfile的文件中，然后再写入MemStore中。 |
| **Store**         | 每store，对应一个列族，包含memstore和storefile               |
| **MenStore**      | 写缓存，由于HFile中的数据要求是有序的，所以数据是先存储在MemStore中，排好序后，等到达刷写时机才会刷写到HFile，每次刷写都会形成一个新的HFile |
| **StoreFile**     | 保存实际数据的物理文件，StoreFile以Hfile的形式存储在HDFS上。每个Store会有一个或多个StoreFile（HFile），数据在每个StoreFile中都是有序的。 |

### 2.写流程

![hbase写流程](C:\Users\lenovo\Desktop\bigdata\hbase\hbase写流程.png)

```
写流程：
1）Client先访问zookeeper，获取hbase:meta表位于哪个Region Server。
  list_namespace_tables "hbase"
  scan "hbase:meta"
2）访问对应的Region Server，获取hbase:meta表，根据读请求的namespace:table/rowkey，查询出目标数据位于哪个Region Server中的哪个Region中。并将该table的region信息以及meta表的位置信息缓存在客户端的meta cache，方便下次访问。
3）与目标Region Server进行通讯；
4）将数据顺序写入（追加）到WAL；
5）将数据写入对应的MemStore，数据会在MemStore进行排序；
6）向客户端发送ack；
7）等达到MemStore的刷写时机后，将数据刷写到HFile。

```

#### 1.memstored flush

##### 1.region刷写机制

* **hbase.hregion.memstore.flush.size**

```
某个memstore的大小达到了hbase.hregion.memstore.flush.size（默认值128M），其所在region的所有memstore都会刷写。
```

* **hbase.hregion.memstore.block.multiplier**（默认值4）**hbase.hregion.memstore.flush.size**（默认值128M）

```
所有 MemStore 的大小总和达到了设定值128*4，该 Region 在memstore flush 完成前会 block 新的更新请求
```

##### 2.regionserver刷写机制

* result = java_heapsize

  *hbase.regionserver.global.memstore.size（默认值0.4）

  *hbase.regionserver.global.memstore.size.lower.limit（默认值0.95）

  相乘的结果

```
当region server中memstore的总大小达到result,region会按照其所有memstore的大小顺序（由大到小）依次进行刷写。直到region server中所有memstore的总大小减小到上述值以下
```

* result = java_heapsize

  *hbase.regionserver.global.memstore.size（默认值0.4）

```
当region server中memstore的总大小达到result,会阻止继续往所有的memstore写数据
```

##### 3.时间刷写机制

* **hbase.regionserver.optionalcacheflushinterval（默认1小时）**

```
到达自动刷写的时间，也会触发memstore flush。自动刷新的时间间隔由该属性进行配置
```

##### 4.wal文件数量刷写

* **hbase.regionserver.max.logs**（无法设置）

```
当WAL文件的数量超过hbase.regionserver.max.logs，region会按照时间顺序依次进行刷写，直到WAL文件数量减小到hbase.regionserver.max.logs以下（该属性名已经废弃，现无需手动设置，最大值为32）
```

### 3.读流程

* 原理图

![hbase_read1](C:\Users\lenovo\Desktop\bigdata\hbase\hbase_read1.png)

![hbase_read2](C:\Users\lenovo\Desktop\bigdata\hbase\hbase_read2.png)



* 流程

```
读流程
1）Client先访问zookeeper，获取hbase:meta表位于哪个Region Server。
2）访问对应的Region Server，获取hbase:meta表，根据读请求的namespace:table/rowkey，查询出目标数据位于哪个Region Server中的哪个Region中。并将该table的region信息以及meta表的位置信息缓存在客户端的meta cache，方便下次访问。
3）与目标Region Server进行通讯；
4）分别在MemStore和Store File（HFile）中查询目标数据，并将查到的所有数据进行合并。此处所有数据是指同一条数据的不同版本（time stamp）或者不同的类型（Put/Delete）。
5）将查询到的新的数据块（Block，HFile数据存储单元，默认大小为64KB）缓存到Block Cache。
6）将合并后的最终结果返回给客户端。

```

#### 1.读操作StoreFile

##### 1.StoreFile Compaction

* 分类

```
由于memstore每次刷写都会生成一个新的HFile，且同一个字段的不同版本（timestamp）和不同类型（Put/Delete）有可能会分布在不同的HFile中，因此查询时需要遍历所有的HFile。为了减少HFile的个数，以及清理掉过期和删除的数据，会进行StoreFile Compaction。
Compaction分为两种，分别是Minor Compaction和Major Compaction。Minor Compaction会将临近的若干个较小的HFile合并成一个较大的HFile，并清理掉部分过期和删除的数据。Major Compaction会将一个Store下的所有的HFile合并成一个大HFile，并且会清理掉所有过期和删除的数据。

```

* Major Compaction参数设置为0

```
不自动去合并大文件，因为时间不能固定，容易业务访问大的时间发生，一半手动合并
```

#### 2.Region Split

* 意义

```
默认情况下，每个Table起初只有一个Region，随着数据的不断写入，Region会自动进行拆分。刚拆分时，两个子Region都位于当前的Region Server，但处于负载均衡的考虑，HMaster有可能会将某个Region转移给其他的Region Server。
```

* Region Split时机

```
1.当1个region中的某个Store下所有StoreFile的总大小超过hbase.hregion.max.filesize，该Region就会进行拆分（0.94版本之前）。
```

```
2.当1个region中的某个Store下所有StoreFile的总大小超过Min(initialSize*R^3 ,hbase.hregion.max.filesize")，该Region就会进行拆分。其中initialSize的默认值为2*hbase.hregion.memstore.flush.size，R为当前Region Server中属于该Table的Region个数（0.94版本之后）。
具体的切分策略为：
第一次split：1^3 * 256 = 256MB 
第二次split：2^3 * 256 = 2048MB 
第三次split：3^3 * 256 = 6912MB 
第四次split：4^3 * 256 = 16384MB > 10GB，因此取较小的值10GB 
后面每次split的size都是10GB了。

```

```
3.Hbase 2.0引入了新的split策略：如果当前RegionServer上该表只有一个Region，按照2 * hbase.hregion.memstore.flush.size分裂，否则按照hbase.hregion.max.filesize分裂。
```

### 3.hbase优化

#### 1.预分区

* 场景

```
每一个region维护着startRow与endRowKey，如果加入的数据符合某个region维护的rowKey范围，则该数据交给这个region维护。那么依照这个原则，我们可以将数据所要投放的分区提前大致的规划好，以提高HBase性能。
```

* 手动设定预分区

```
create 'staff1','info',SPLITS => ['1000','2000','3000','4000']
```

* 生成16进制列预分区

```
create 'staff2','info',{NUMREGIONS => 15, SPLITALGO => 'HexStringSplit'}
```

* 按照文件中设置规则预分区

```
aaaa
bbbb
cccc
dddd
```

```
create 'staff3','info',SPLITS_FILE => 'splits.txt'
```

```
//自定义算法，产生一系列Hash散列值存储在二维数组中
byte[][] splitKeys = 某个散列值函数
//创建HbaseAdmin实例
HBaseAdmin hAdmin = new HBaseAdmin(HbaseConfiguration.create());
//创建HTableDescriptor实例
HTableDescriptor tableDesc = new HTableDescriptor(tableName);
//通过HTableDescriptor实例和散列值二维数组创建带有预分区的Hbase表
hAdmin.createTable(tableDesc, splitKeys);

```

#### ２.rowkey+预分区案例（ToDO）

```

```

#### 3.内存优化

* 堆内存的大小设计

```
HBase操作过程中需要大量的内存开销，毕竟Table是可以缓存在内存中的，但是不建议分配非常大的堆内存，因为GC过程持续太久会导致RegionServer处于长期不可用状态，一般16~36G内存就可以了，如果因为框架占用内存过高导致系统内存不足，框架一样会被系统服务拖死
```

#### 4.基础优化（基于hbase-szie.xml）

* zk会话超时

```
属性：zookeeper.session.timeout
解释：默认值为90000毫秒（90s）。当某个RegionServer挂掉，90s之后Master才能察觉到。可适当减小此值，以加快Master响应，可调整至60000毫秒

```

* rpc监听数量

```
属性：hbase.regionserver.handler.count
解释：默认值为30，用于指定RPC监听的数量，可以根据客户端的请求数进行调整，读写请求较多时，增加此值。

```

* 手动Major Compaction

```
属性：hbase.hregion.majorcompaction
解释：默认值：604800000秒（7天）， Major Compaction的周期，若关闭自动Major Compaction，可将其设为0
```

* HStore文件大小

```
属性：hbase.hregion.max.filesize
解释：默认值10737418240（10GB），如果需要运行HBase的MR任务，可以减小此值，因为一个region对应一个map任务，如果单个region过大，会导致map任务执行时间过长。该值的意思就是，如果HFile的大小达到这个数值，则这个region会被切分为两个Hfile。

```

* HBase客户端缓存

```
属性：hbase.client.write.buffer
解释：默认值2097152bytes（2M）用于指定HBase客户端缓存，增大该值可以减少RPC调用次数，但是会消耗更多内存，反之则反之。一般我们需要设定一定的缓存大小，以达到减少RPC次数的目的。

```

* **scan.next****扫描HBase所获取的行数**

```
属性：hbase.client.scanner.caching
解释：用于指定scan.next方法获取的默认行数，值越大，消耗内存越大。
```

* BlockCache占用RegionServer堆内存的比例

```
属性：hfile.block.cache.size
解释：默认0.4，读请求比较多的情况下，可适当调大

```

* MemStore占用RegionServer堆内存的比例

```
属性：hbase.regionserver.global.memstore.size
解释：默认0.4，写请求较多的情况下，可适当调大

```

