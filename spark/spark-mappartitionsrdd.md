## 一.Transformation



| 条目       | 解释                                             |
| ---------- | ------------------------------------------------ |
| h3标题有*  | 产生shuffle落盘操作(源码里有分区参数都要shuffle) |
| h3标题有$@ | 预聚合操作                                       |
| !          | 需要Todo                                         |
| &          | 只能作用PairRDD(kv形式键值对)                    |
|            |                                                  |

```
源码里有partition分区参数的多半都是设计到shuffle
```

### 1.map

* 源码

```scala
  /**
   * Return a new RDD by applying a function to all elements of this RDD.
   */ 
def map[U: ClassTag](f: T => U): RDD[U] = withScope {
    val cleanF = sc.clean(f)
    new MapPartitionsRDD[U, T](this, (_, _, iter) => iter.map(cleanF))
  }
```

* sc.clean分析

```
sc.clean() 去除闭包中不能序列话的外部引用变量。Scala支持闭包，闭包会把它对外的引用(闭包里面引用了闭包外面的对像)保存到自己内部，这个闭包就可以被单独使用了，而不用担心它脱离了当前的作用域；但是在spark这种分布式环境里，如果对外部的引用是不可serializable的，它就不能正确被发送到worker节点上去了；实际上sc.clean函数调用的是ClosureCleaner.clean()；ClosureCleaner.clean()通过递归遍历闭包里面的引用，检查不能serializable的, 去除unused的引用；
```

* map作用

```
map函数是一个粗粒度的操作，对于一个RDD来说，会使用迭代器对分区进行遍历，然后针对一个分区使用你想要执行的操作f, 然后返回一个新的RDD。其实可以理解为rdd的每一个元素都会执行同样的操作。

//map参数提示
Int => U(不确定)
map算子表示将数据源中的每一条数据进行处理
map算子的参数是函数类型： Int => U(不确定)
```

### 2.flatmap

* 源码

```scala
  /**
   *  Return a new RDD by first applying a function to all elements of this
   *  RDD, and then flattening the results.
   */
  def flatMap[U: ClassTag](f: T => TraversableOnce[U]): RDD[U] = withScope {
    val cleanF = sc.clean(f)
    new MapPartitionsRDD[U, T](this, (_, _, iter) => iter.flatMap(cleanF))
  }sq
```

* flatmap

```
允许一次map方法中输出多个对象，而不是map中的一个对象经过函数转换成另一个对象。
```

* 案例

```scala
 val rdd1 = sc.makeRDD(
	  List(List(1,2), List(3,4))
      val rdd3 = rdd1.flatMap(
          //不可以省略为_，输出和输出一致时
          list => list)
```

* 案例

```scala
    val rdd = sc.makeRDD(
      List(List(1,2),3,List(4,5))
    )
//使用大括号时可以使用模式匹配
    rdd.flatMap {
      case list : List[_] => list
      case other => List(other)
    }.collect().foreach(println(_))
```



### 3.mapPartitions 

* 源码

```scala
  /**
   * Return a new RDD by applying a function to each partition of this RDD.
   *
   * `preservesPartitioning` indicates whether the input function preserves the partitioner, which
   * should be `false` unless this is a pair RDD and the input function doesn't modify the keys.
   */
  def mapPartitions[U: ClassTag](
      f: Iterator[T] => Iterator[U],
      preservesPartitioning: Boolean = false): RDD[U] = withScope {
    val cleanedF = sc.clean(f)
    new MapPartitionsRDD(
      this,
      (_: TaskContext, _: Int, iter: Iterator[T]) => cleanedF(iter),
      preservesPartitioning)
  }
```

* 案例

```scala
        val rdd = sc.makeRDD(List(1,2,3,4), 2)
        // 获取每个数据分区的最大值
        // 【1，2】【3，4】
        val rdd1 = rdd.mapPartitions(
            list => {
                val max = list.max
                //Iterator(elem.max)  or   x.toList.iterator  or List(max).iterator
                List(max).iterator
            }
        )
```

* mappartitions作用

```
返回分区数量数的Iterator;迭代器Iterator提供了一种访问集合的方法，可以通过while或者for循环来实现对迭代器的遍历
```

### 4.mapPartitionsWithIndex

* 源码

```scala
  /**
   * Return a new RDD by applying a function to each partition of this RDD, while tracking the index
   * of the original partition.
   *
   * `preservesPartitioning` indicates whether the input function preserves the partitioner, which
   * should be `false` unless this is a pair RDD and the input function doesn't modify the keys.
   */
  def mapPartitionsWithIndex[U: ClassTag](
      f: (Int, Iterator[T]) => Iterator[U],
      preservesPartitioning: Boolean = false): RDD[U] = withScope {
    val cleanedF = sc.clean(f)
    new MapPartitionsRDD(
      this,
      (_: TaskContext, index: Int, iter: Iterator[T]) => cleanedF(index, iter),
      preservesPartitioning)
  }
```

* 分析

```
=> 参数类型f: (Int, Iterator[T]) => Iterator[U]
=> 第一个参数分区的索引号
```

* 案例(熟悉迭代器使用)

```scala
    val rdd = sc.makeRDD(List(1,2,3,4,5,6), 3)
    //(part-0,List(2, 1)) (part-1,List(5, 4, 3))
    val rdd1 = rdd.mapPartitionsWithIndex(
      (num,iter)=>{
        val map = mutable.Map[String,ListBuffer[Int]]()
        val indexStr = "part-" + num
        val list= ListBuffer[Int]()
        while(iter.hasNext){
            val i = iter.next()
            list.append(i)
          }
        map.put(indexStr,list)
        map.iterator
      }
    )
```

### 5.glom

* 源码

```scala
/**
 * Return an RDD created by coalescing（合并） all elements within each partition into an array.
 */
def glom(): RDD[Array[T]] = withScope {
  new MapPartitionsRDD[Array[T], T](this, (_, _, iter) => Iterator(iter.toArray))
}
```

* 案例

```
    val rdd = sc.makeRDD(List(1,2,3,4,5,6), 2)
    rdd.glom().collect().foreach(elem=>println(elem.mkString(",")))
```

* 案例2(对照flatmap)

```scala
    //  扁平化-> 层级化
    val rdd : RDD[Int] = sc.makeRDD(List(1,2,3,4,5,6), 2)
    val rdd1: RDD[Array[Int]] = rdd.glom()
    rdd1.map(_.max).collect().sum
```

### 6.groupby*

* 源码

```scala
  /**
   * Return an RDD of grouped items. Each group consists of a key and a sequence of elements
   * mapping to that key. The ordering of elements within each group is not guaranteed,(保证) and
   * may even differ each time the resulting RDD is evaluated（求值）.
   *
   * @note This operation may be very expensive. If you are grouping in order to perform an
   * aggregation (such as a sum or average) over each key, using `PairRDDFunctions.aggregateByKey`
   * or `PairRDDFunctions.reduceByKey` will provide much better performance.
   */
  def groupBy[K](f: T => K)(implicit kt: ClassTag[K]): RDD[(K, Iterable[T])] = withScope {
    //继续进入源码
    groupBy[K](f, defaultPartitioner(this))
  }
```

* 源码2

```scala
  def groupBy[K](f: T => K, p: Partitioner)(implicit kt: ClassTag[K], ord: Ordering[K] = null)
      : RDD[(K, Iterable[T])] = withScope {
    //继续进入源码      
    this.map(t => (cleanF(t), t)).groupByKey(p)
          
  }
```

* 源码3

```scala
  /**
   * Group the values for each key in the RDD into a single sequence. Allows controlling the
   * partitioning of the resulting key-value pair RDD by passing a Partitioner.
   * The ordering of elements within each group is not guaranteed, and may even differ
   * each time the resulting RDD is evaluated.
   *
   * @note This operation may be very expensive. If you are grouping in order to perform an
   * aggregation (such as a sum or average) over each key, using `PairRDDFunctions.aggregateByKey`
   * or `PairRDDFunctions.reduceByKey` will provide much better performance.
   *
   * @note As currently implemented, groupByKey must be able to hold all the key-value pairs for any
   * key in memory. If a key has too many values, it can result in an `OutOfMemoryError`.
   */
  def groupByKey(partitioner: Partitioner): RDD[(K, Iterable[V])] = self.withScope {
    // groupByKey shouldn't use map side combine because map side combine does not
    // reduce the amount of data shuffled and requires all map side data be inserted
    // into a hash table, leading to more objects in the old gen.
    val createCombiner = (v: V) => CompactBuffer(v)
    val mergeValue = (buf: CompactBuffer[V], v: V) => buf += v
    val mergeCombiners = (c1: CompactBuffer[V], c2: CompactBuffer[V]) => c1 ++= c2
    val bufs = combineByKeyWithClassTag[CompactBuffer[V]](
      createCombiner, mergeValue, mergeCombiners, partitioner, mapSideCombine = false)
    bufs.asInstanceOf[RDD[(K, Iterable[V])]]
  }
```

* 流程

```scala
1.groupBy[K](f: T => K)
2.groupBy[K](f, defaultPartitioner(this))
3.this.map(t => (cleanF(t), t)).groupByKey(p)
4.groupByKey(partitioner: Partitioner)
example
List("Hello", "hive", "hbase", "Hadoop")
val rdd1 = rdd.groupBy(_.substring(0, 1)) //elem=>elem.substring(0,1)==function
// groupBy(elem=>elem.substring(0,1)) 传递给
// groupBy[K](elem=>elem.substring(0,1), defaultPartitioner(this)) 传递给
// this.map(t => (cleanF(t), t))相当于this.map(t => (t=>t.substring(0,1), t)) t是map每一行的数据 处理后的数据应该是(H,Hello),(h,hive),(h,hbase),(H,Hadoop)
// (H,Hello),(h,hive),(h,hbase),(H,Hadoop)进行groupbyKey(p)的操作
//Todo补充groupbuKey的源码 为什么返回的是一个Map,kv结构的数据

```

* 返回compactBuffer

```
According to Spark's documentation, it is an alternative to ArrayBuffer that results in better performance because it allocates less memory
```

### 7.groupbyKey*&

* 实例

```
// 2. groupBy按照指定的规则进行分组，groupByKey必须根据key对value分组
// 3. 返回结果类型
//    groupByKey => (String, Iterable[Int])
//    groupBy    => (String, Iterable[(String, Int)])

// groupByKey算子将相同key数据的value分在一个组中
```

```scala
// TODO 算子 - 转换 - groupByKey
val rdd : RDD[(String, Int)] = sc.makeRDD(
    List(
         ("a", 1),
         ("a", 1),
         ("a", 1)
    )
)
//(a,CompactBuffer((a,1), (a,1), (a,1)))
val value: RDD[(String, Iterable[(String, Int)])] = rdd.groupBy(_._1)
//(a,CompactBuffer(1, 1, 1))
val rdd1: RDD[(String, Iterable[Int])] = rdd.groupByKey()
val rdd2: RDD[(String, Int)] = rdd1.mapValues(_.size)
```

### 8.filter

* 源码

```scala
/**
 * Return a new RDD containing only the elements that satisfy a predicate(断言).
 */
def filter(f: T => Boolean): RDD[T] = withScope {
  val cleanF = sc.clean(f)
  new MapPartitionsRDD[T, T](
    this,
    (_, _, iter) => iter.filter(cleanF),
    preservesPartitioning = true)
}
```

* 案例

```scala
// filter算子可以按照指定的规则对每一条数据进行筛选过滤
// 数据处理结果为true，表示数据保留，如果为false，数据就丢弃
val rdd1 = rdd.filter(
   num => num % 2 == 1
)
```

* 案例2 先根据时间段过滤，再去统计

```scala
    val lines = sc.textFile("access.log")
    lines.filter(
      line => {
        //line.contains("17/05/2020")
        val datas = line.split(" ")
        val time = datas(3)
        time.startsWith("17/05/2020")
      }
    ).map(
      line => {
        val datas = line.split(" ")
        datas(6)
      }
    )
```

### 9.sample

* 案例

```scala
val rdd : RDD[Int] = sc.makeRDD(1 to 10)
    // 抽取数据，采样数据
    // 第一个参数表示抽取数据的方式：true. 抽取放回，false. 抽取不放回
    // 第二个参数和第一个参数有关系
    //     如果抽取不放回的场合：参数表示每条数据被抽取的几率
    //     如果抽取放回的场合：参数表示每条数据希望被重复抽取的次数
    // 第三个参数是【随机数】种子
    //     随机数不随机，所谓的随机数，其实是通过随机算法获取的一个数
    //     3 = xxxxx(10)
    //     7 = xxxxx(3)
    //val rdd1: RDD[Int] = rdd.sample(false, 0.5)
    //val rdd1: RDD[Int] = rdd.sample(true, 2)
val rdd1: RDD[Int] = rdd.sample(false, 0.5, 2).collect.foreach(println)
```

### 10.distinct

* 源码

```scala
/**
   * Return a new RDD containing the distinct elements in this RDD.去重
   */
  def distinct(numPartitions: Int)(implicit ord: Ordering[T] = null): RDD[T] = withScope {
    def removeDuplicatesInPartition(partition: Iterator[T]): Iterator[T] = {
      // Create an instance of external append only map which ignores values.
      val map = new ExternalAppendOnlyMap[T, Null, Null](
        createCombiner = _ => null,
        mergeValue = (a, b) => a,
        mergeCombiners = (a, b) => a)
      map.insertAll(partition.map(_ -> null))
      map.iterator.map(_._1)
    }
    partitioner match {
      case Some(_) if numPartitions == partitions.length =>
        mapPartitions(removeDuplicatesInPartition, preservesPartitioning = true)
      case _ => map(x => (x, null)).reduceByKey((x, _) => x, numPartitions).map(_._1)
    }
  }
```

### 11.reducebyKey*@&!

* 源码

```scala
/**
   * Merge(结合) the values for each key using an associative(结合) and commutative(交换) reduce function. This will
   * also perform the merging locally on each mapper before sending results to a reducer, similarly
   * to a "combiner"(合成器) in MapReduce. Output will be hash-partitioned with the existing partitioner/
   * parallelism(平行) level.
   */
// 返回类型Rdd(k,v) func参数处理的是v
  def reduceByKey(func: (V, V) => V): RDD[(K, V)] = self.withScope {
     //继续进入源码
    reduceByKey(defaultPartitioner(self), func)
  }
```

* 源码2

```scala
def reduceByKey(partitioner: Partitioner, func: (V, V) => V): RDD[(K, V)] = self.withScope {
    // 继续进入源码
    combineByKeyWithClassTag[V]((v: V) => v, func, func, partitioner)
  }
```

* 源码3

```scala
 /**
   * Generic function to combine the elements for each key using a custom set of aggregation
   * functions. Turns an RDD[(K, V)] into a result of type RDD[(K, C)], for a "combined type" C
   *
   * Users provide three functions:
   *
   *  - `createCombiner`, which turns a V into a C (e.g., creates a one-element list)
   *  - `mergeValue`, to merge a V into a C (e.g., adds it to the end of a list)
   *  - `mergeCombiners`, to combine two C's into a single one.
   *
   * In addition, users can control the partitioning of the output RDD, and whether to perform
   * map-side aggregation (if a mapper can produce multiple items with the same key).
   *
   * @note V and C can be different -- for example, one might group an RDD of type
   * (Int, Int) into an RDD of type (Int, Seq[Int]).
   */

/**
reduce方法对每一个key的值作merge操作，这里在将结果发送给reducer之前，会现在每一个mapper的本地执行merge操作，类似于MapReduce的combiner。这与官方文档中提到的reduceByKey and aggregateByKey create these structures on the map side, and 'ByKey operations generate these on the reduce side.
*/

  def combineByKeyWithClassTag[C](
      createCombiner: V => C, //创建聚合器
      mergeValue: (C, V) => C, //每一个Executor内部执行的聚合方法
      mergeCombiners: (C, C) => C, //不同Executor之间执行的聚合器
      partitioner: Partitioner, //提供分区的策略
      mapSideCombine: Boolean = true, //map端开启数据合并策略
      serializer: Serializer = null)(implicit ct: ClassTag[C]): RDD[(K, C)] = self.withScope {
    require(mergeCombiners != null, "mergeCombiners must be defined") // required as of Spark 0.9.0
      /**
      如果rdd中保存的数据类型是arrays，这个时候HashPartitioner是不可用的
      如果rdd中保存的数据类型是arrays，在map端作combine操作也是不允许的。
      */
    if (keyClass.isArray) {
      if (mapSideCombine) {
        throw new SparkException("Cannot use map-side combining with array keys.")
      }
      if (partitioner.isInstanceOf[HashPartitioner]) {
        throw new SparkException("HashPartitioner cannot partition array keys.")
      }
    }
    val aggregator = new Aggregator[K, V, C](
      self.context.clean(createCombiner),
      self.context.clean(mergeValue),
      self.context.clean(mergeCombiners))
/**
self变量引用的rdd,当前rdd（也就是self变量引用的rdd）的partitioner跟传入的partitioner一不一样
	如果不一样，分支的代码会返回一个shuffledRDD对象，并把要作用在rdd上的相关操作，包括partitioner，serializer，aggregator，mapSideCombine一并保存在ShuffledRDD中返回，，并没有实际执行rdd得聚合方法。
	如果一样，self作了一个mapPartitions操作，最终返回了一个mapPartitionsRDD。也就是说，当子rdd和它所依赖的父rdd使用了相同的partitioner时，就不需要再进行shuffle操作了。这里其实也很好理解，如果父rdd用的和子rdd相同的partitioner，那么父rdd划分出的分片就已经符合子rdd的需求了，这个时候再作shuffle没有意义

*/
    if (self.partitioner == Some(partitioner)) {
//An RDD that applies the provided function to every partition of the parent RDD.
      self.mapPartitions(iter => {
        val context = TaskContext.get()
// Todo 后面在分析aggregator.combineValuesByKey
        new InterruptibleIterator(context, aggregator.combineValuesByKey(iter, context))
      }, preservesPartitioning = true)
    } else {
      // 参数为[K,V,C]，代表输入的RDD类型为(K,V)类型，返回的RDD数据类型为C
      new ShuffledRDD[K, V, C](self, partitioner)
        .setSerializer(serializer)
        .setAggregator(aggregator)
        .setMapSideCombine(mapSideCombine)
    }
  }
```

* 优点

```
map端会先对本地的数据进行combine操作，然后将数据写入给下个stage的每个task创建的文件中
使用reduceByKey对性能的提升如下：
本地聚合后，在map端的数据量变少，减少了磁盘IO，也减少了对磁盘空间的占用；
本地聚合后，下一个stage拉取的数据量变少，减少了网络传输的数据量；
本地聚合后，在reduce端进行数据缓存的内存占用减少；
本地聚合后，在reduce端进行聚合的数据量减少。
```

* 案例

```scala
val dataRDD1 = sc.makeRDD(List(("a",1),("a",2),("c",3),("d",1),("e",2),("c",2)))
// dataRDD1.saveAsTextFile("output")
// val dataRDD2 = dataRDD1.reduceByKey(_+_).collect().foreach(println(_))
// (v1,v2)=>v1+v2    
val dataRDD3 = dataRDD1.reduceByKey(_+_,2)   
dataRDD3.saveAsTextFile("output")
dataRDD3.collect().foreach(println(_))
```

### 12.coalesce*

* 案例

```scala
val rdd : RDD[Int] = sc.makeRDD(
   List(1,2,3,4,5,6), 3
)
// 缩减 (合并)， 默认情况下缩减分区不会shuffle,参数为true可发送shuffle
//val rdd1: RDD[Int] = rdd.coalesce(2)
// 这种方式在某些情况下，无法解决数据倾斜问题，所以还可以在缩减分区的同时，进行数据的shuffle操作
val rdd2: RDD[Int] = rdd.coalesce(2, true)  //output1 145 236
val rdd3: RDD[Int] = rdd.coalesce(2)    //output1 12 3456
rdd.saveAsTextFile("output")
rdd2.saveAsTextFile("output1")
```

### 13.repartition*

* 源码

```
调用的coalesce方法
```

* 实例

```scala
// 转换 - 扩大分区
val rdd : RDD[Int] = sc.makeRDD(List(1,2,3,4,5,6), 2)
// 扩大分区 - repartition
// 在不shuffle的情况下，coalesce算子扩大分区是没有意义的。
val rdd1: RDD[Int] = rdd.coalesce(3, true)
val rdd1: RDD[Int] = rdd.repartition(3)
rdd.saveAsTextFile("output")
rdd1.saveAsTextFile("output1")
```

### 14.sortby*

* 源码

```scala
  /**
   * Return this RDD sorted by the given key function.
   */
  def sortBy[K](
      f: (T) => K,
      ascending: Boolean = true,
      numPartitions: Int = this.partitions.length)
      (implicit ord: Ordering[K], ctag: ClassTag[K]): RDD[T] = withScope {
    // 继续进入源码
    this.keyBy[K](f)
        .sortByKey(ascending, numPartitions)
        .values
  }

  /**
   * Creates tuples of the elements in this RDD by applying `f`.
   把传递进来的每个元素作用在f函数，返回tuple
   */
  def keyBy[K](f: T => K): RDD[(K, T)] = withScope {
    val cleanedF = sc.clean(f)
    map(x => (cleanedF(x), x))
  }
```

* 源码

```scala
  /**
   * Sort the RDD by key, so that each partition contains a sorted range of the elements. Calling
   * `collect` or `save` on the resulting RDD will return or output an ordered list of records
   * (in the `save` case, they will be written to multiple `part-X` files in the filesystem, in
   * order of the keys).
   */
  // TODO: this currently doesn't work on P other than Tuple2!
  def sortByKey(ascending: Boolean = true, numPartitions: Int = self.partitions.length)
      : RDD[(K, V)] = self.withScope
  {
      //     val samplePointsPerPartitionHint: Int = 20) 抽样20
    val part = new RangePartitioner(numPartitions, self, ascending)
    new ShuffledRDD[K, V, V](self, part)
      .setKeyOrdering(if (ascending) ordering else ordering.reverse)
  }
```

* 实例

```scala
val rdd : RDD[Int] = sc.makeRDD(
  List(1,4,3,2,6,5),2
)
val rdd1: RDD[Int] = rdd.sortBy(num => num, false)
println(rdd1.collect.mkString(","))
```

* sortby sortbykey区别

```
sortby 处理普通RDD
sortbykey 处理pairRDD
```



### 15.partitionby*&

* 源码

```scala
  /**
   * Return a copy of the RDD partitioned using the specified partitioner.
   partitionBy只能作用于PairRDD
   */
  def partitionBy(partitioner: Partitioner): RDD[(K, V)] = self.withScope {
    if (keyClass.isArray && partitioner.isInstanceOf[HashPartitioner]) {
      throw new SparkException("HashPartitioner cannot partition array keys.")
    }
    if (self.partitioner == Some(partitioner)) {
      self
    } else {
      new ShuffledRDD[K, V, V](self, partitioner)
    }
  }
```

* 案例

```scala
val rdd : RDD[Int] = sc.makeRDD(
  List(1,2,3,4),2
)
// partitionBy算子是根据指定的规则对每一条数据进行重分区
// repartition : 强调分区数量的变化，数据怎么变不关心
// partitionBy : 关心数据的分区规则


// 下面调用RDD对象的partitionBy方法一定会报错。
// 二次编译（隐式转换）
// RDD => PairRDDFunctions
// HashPartitioner是Spark中默认shuffle分区器

val rdd1: RDD[(Int, Int)] = rdd.map((_, 1))
rdd1.partitionBy(new HashPartitioner(2)).saveAsTextFile("output");

```

* 优势

```
partitionBy，只会产生一次shuffle：partitionBy一次shuffle过后，相同的key的所有(K,V)对在同一个Partition中，reduceByKey只需要在每个Partition当中分别计算即可以，无需shuffle
```

### 16.aggregatebykey*@&

* 源码

```scala
  /**
   * Aggregate the values of each key, using given combine functions and a neutral "zero value".
   * This function can return a different result type, U, than the type of the values in this RDD,
   * V. Thus, we need one operation for merging a V into a U and one operation for merging two U's,
   * as in scala.TraversableOnce. The former operation is used for merging values within a
   * partition, and the latter is used for merging values between partitions. To avoid memory
   * allocation, both of these functions are allowed to modify and return their first argument
   * instead of creating a new U.
   */
  def aggregateByKey[U: ClassTag](zeroValue: U)(seqOp: (U, V) => U,
      combOp: (U, U) => U): RDD[(K, U)] = self.withScope {
    //继续进入源码  
    aggregateByKey(zeroValue, defaultPartitioner(self))(seqOp, combOp)
  }
```

* 源码

```scala
  def aggregateByKey[U: ClassTag](zeroValue: U, partitioner: Partitioner)(seqOp: (U, V) => U,
      combOp: (U, U) => U): RDD[(K, U)] = self.withScope {
    // Serialize the zero value to a byte array so that we can get a new clone of it on each key
    val zeroBuffer = SparkEnv.get.serializer.newInstance().serialize(zeroValue)
    val zeroArray = new Array[Byte](zeroBuffer.limit)
    zeroBuffer.get(zeroArray)

    lazy val cachedSerializer = SparkEnv.get.serializer.newInstance()
    val createZero = () => cachedSerializer.deserialize[U](ByteBuffer.wrap(zeroArray))

    // We will clean the combiner closure later in `combineByKey`
    val cleanedSeqOp = self.context.clean(seqOp)
    //继续进入源码,参见reducebyKey的解释源码
    combineByKeyWithClassTag[U]((v: V) => cleanedSeqOp(createZero(), v),
      cleanedSeqOp, combOp, partitioner)
  }

```

* 实例

```
aggregateByKey算子存在函数柯里化
第一个参数列表中有一个参数
     参数为零值，表示计算初始值 zero, z, 用于数据进行分区内计算
第二个参数列表中有两个参数
     第一个参数表示 分区内计算规则
     第二个参数表示 分区间计算规则

val rdd = sc.makeRDD(
  List(
    ("a",1),("a",2),("b",3),
    ("b",4),("b",5),("a",6)
  ),
  2
)
val rdd1 = rdd.aggregateByKey(5)(
  (x, y) => {
    math.max(x, y)
  },
  (x, y) => {
    x + y
  }
)
example2:
    val data = sc.parallelize(
      List(
        ("13909029812",("20170507","http://www.baidu.com")),
        ("18089376778",("20170401","http://www.google.com")),
        ("18089376778",("20170508","http://www.taobao.com")),
        ("13909029812",("20170507","http://www.51cto.com"))
      )
    )
    data.aggregateByKey(scala.collection.mutable.Set[(String, String)]())(
      (set, item) => {
        set += item
      },
      (set1, set2) => {
        set1 union set2
      }).mapValues(x => x.toIterable).collect().foreach(println(_))
```

* 解释

```scala

aggregateByKey[U: ClassTag](zeroValue: U)(seqOp: (U, V) => U,
      combOp: (U, U) => U): RDD[(K, U)]
zeroValue: U	//初始化U1
seqOp: (U, V) => U	//(初始化U1,每条数据value)=>类型和初始化一致结果为U2
combOp: (U, U) => U	//(分区间1的U2,分区间2的U2)
RDD[(K, U)]	//返回类型还是（k类型不变,U类型改变为其他类型集合）
```

### 17.foldbykey*&!

* 实例

```scala
//如果aggregateByKey算子的分区内计算逻辑和分区间计算逻辑相同，那么可以使用foldByKey算子简化
val rdd3 = rdd.foldByKey(0)(_+_)
```

### 18.combineByKey*&

* 源码

```scala
  /**
   * Simplified version of combineByKeyWithClassTag that hash-partitions the resulting RDD using the
   * existing partitioner/parallelism level. This method is here for backward compatibility. It
   * does not provide combiner classtag information to the shuffle.
   *
   * @see `combineByKeyWithClassTag`
   */
  def combineByKey[C](
      createCombiner: V => C,
      mergeValue: (C, V) => C,
      mergeCombiners: (C, C) => C): RDD[(K, C)] = self.withScope {
    //继续进入源码,参见reducebyKey的解释源码
    combineByKeyWithClassTag(createCombiner, mergeValue, mergeCombiners)(null)
  }
```

* 源码

```scala
  /**
   * Simplified version of combineByKeyWithClassTag that hash-partitions the resulting RDD using the
   * existing partitioner/parallelism level.
   */
  def combineByKeyWithClassTag[C](
      createCombiner: V => C,
      mergeValue: (C, V) => C,
      mergeCombiners: (C, C) => C)(implicit ct: ClassTag[C]): RDD[(K, C)] = self.withScope {
//继续进入源码,参见reducebyKey的解释源码
      combineByKeyWithClassTag(createCombiner, mergeValue, mergeCombiners, defaultPartitioner(self))
  }

```

* 实例

```scala
//求每个key的平均值
val rdd = sc.makeRDD(
  List(
    ("a", 1), ("a", 2), ("b", 3),
    ("b", 4), ("b", 5), ("a", 6)
  ),
  2
)
val rdd2 = rdd.combineByKey(
  num => (num, 1),
  //需要加上类型注解，否则scala语法无法推断出其类型  
  (x : (Int, Int), y) => {
    (x._1 + y, x._2 + 1)
  },
  //需要加上类型注解，否则scala语法无法推断出其类型  
  ( x : (Int, Int), y:(Int, Int) ) => {
    (x._1 + y._1, x._2 + y._2)
  }
)
```

* 参数使用

```scala
  def combineByKey[C](
      createCombiner: V => C,
      mergeValue: (C, V) => C,
      mergeCombiners: (C, C) => C): RDD[(K, C)] 
// 初始化
createCombiner: V => C, // 每条数据的value,通过函数返回C
// 组内
mergeValue: (C, V) => C, //createcombiner返回的C和每条数据的value 。通过函数返回C
// 组间
mergeCombiners: (C, C) => C //分区1mergevalue返回C，分区2mergevalue返回的C,通过函数返回C
// 返回值
RDD[(K, C)]  //(k：类型不变，V：类型改变)
//combilebyKey(参数1，参数2，参数3) 区别于 aggregatebyKey(参数1)(参数2，参数3)
```

### 19.sortbykey&*&

* 源码

```scala
  /**
   * Sort the RDD by key, so that each partition contains a sorted range of the elements. Calling
   * `collect` or `save` on the resulting RDD will return or output an ordered list of records
   * (in the `save` case, they will be written to multiple `part-X` files in the filesystem, in
   * order of the keys).
   */
  // TODO: this currently doesn't work on P other than Tuple2!
  def sortByKey(ascending: Boolean = true, numPartitions: Int = self.partitions.length)
      : RDD[(K, V)] = self.withScope
  {
      //RangePartitioner，它可以使得相应的范围Key数据分到同一个partition中，然后内部用到了mapPartitions对每个partition中的数据进行排序，而每个partition中数据的排序用到了标准的sort机制，避免了大量数据的shuffle
    val part = new RangePartitioner(numPartitions, self, ascending)
    new ShuffledRDD[K, V, V](self, part)
      // 进入源码
      .setKeyOrdering(if (ascending) ordering else ordering.reverse)
  }
```

* 源码

```scala
/** Set key ordering for RDD's shuffle. */
  def setKeyOrdering(keyOrdering: Ordering[K]): ShuffledRDD[K, V, C] = {
    this.keyOrdering = Option(keyOrdering)
    this
  }
```

* 实例

```scala
    //  ("a", 1)("a", 2)("b", 4) ("c", 3)
    // sortByKey算子就是按照key排序
    val rdd1: RDD[(String, Int)] = rdd.sortByKey(false)
```

* 自定义

```scala
	val rdd = sc.makeRDD(
        List((new User(), 2), (new User(), 1), (new User(), 3), (new User(), 4)))
	//  ("a", 1)("a", 2)("b", 4) ("c", 3)
	// sortByKey算子就是按照key排序
        val rdd1: RDD[(User, Int)] = rdd.sortByKey(false)
        rdd1.collect.foreach(println)
    }
    class User extends Ordered[User]{
        override def compare(that: User): Int = {
            1
        }
    }
```

### 20.cogroup

* 源码

```scala
  /**
   * For each key k in `this` or `other`, return a resulting RDD that contains a tuple with the
   * list of values for that key in `this` as well as `other`.
   */
  def cogroup[W](other: RDD[(K, W)]): RDD[(K, (Iterable[V], Iterable[W]))] = self.withScope {
      //继续进入源码
    cogroup(other, defaultPartitioner(self, other))
  }

```

* 源码

```scala
  /**
   * For each key k in `this` or `other`, return a resulting RDD that contains a tuple with the
   * list of values for that key in `this` as well as `other`.
   */
  def cogroup[W](other: RDD[(K, W)], partitioner: Partitioner)
      : RDD[(K, (Iterable[V], Iterable[W]))] = self.withScope {
    if (partitioner.isInstanceOf[HashPartitioner] && keyClass.isArray) {
      throw new SparkException("HashPartitioner cannot partition array keys.")
    }
    val cg = new CoGroupedRDD[K](Seq(self, other), partitioner)
    cg.mapValues { case Array(vs, w1s) =>
      (vs.asInstanceOf[Iterable[V]], w1s.asInstanceOf[Iterable[W]])
    }
  }
```

* 对比

```
spark中join操作主要针对于两个数据集中相同的key的数据连接
join操作可能会产生笛卡尔乘积，可能会出现shuffle，性能比较差
所以如果能使用其他方式实现同样的功能，不推荐使用join
```

* 案例

```scala
    val rdd1 = sc.makeRDD(List(("a", 1),  ("b", 2), ("c", 3)))
    val rdd2 = sc.makeRDD(List(("a", 4),  ("a", 5), ("a", 6)))
    
    rdd1.cogroup(rdd2).collect().foreach(println(_))
    (a,(CompactBuffer(1),CompactBuffer(4, 5, 6)))
    (b,(CompactBuffer(2),CompactBuffer()))
    (c,(CompactBuffer(3),CompactBuffer()))
```

### 21.ByKey对比

```
如果分区内和分区间计算逻辑相同，并且不需要指定初始值，那么优先使用reduceByKey
如果分区内和分区间计算逻辑相同，并且需要指定初始值，那么优先使用foldByKey
如果分区内和分区间计算逻辑不相同，并且需要指定初始值，那么优先使用aggregateByKey
需要对读入的RDD中数据进行格式转换时，并且要处理分区内和分区间的逻辑，那么优先使用combineByKey
```



## 二.Action

### 1.collect*

* 特点

```
1）以数组Array的形式返回数据集的所有元素
2）rdd直接调用foreach输出,不同分区的数据是在不同的Executor并行输出，没调用collect进行输出的话，元素的顺序可能会跟原顺序不一样
3）rdd先调用collect再foreach输出，调用collect之后，部拉取到Driver端的内存中，形成数据集合，可能会导致内存溢出;
4）collect是按照分区号码进行采集
```

### 2.reduce*

* 特点

```
def reduce(f: (T, T) => T): T
先聚合分区内数据，再聚合分区间数据
```

* 案例

```
val rdd = sc.makeRDD(List(1,4,3,2),2)
// reduce算子
val i: Int = rdd.reduce(_ + _)
```

### 3.count,first,take,takeOrdered*

* takeordered

```scala
  /**
   * Returns the first k (smallest) elements from this RDD as defined by the specified
   * implicit Ordering[T] and maintains the ordering. This does the opposite of [[top]].
   * For example:
   * {{{
   *   sc.parallelize(Seq(10, 4, 2, 12, 3)).takeOrdered(1)
   *   // returns Array(2)
   *
   *   sc.parallelize(Seq(2, 3, 4, 5, 6)).takeOrdered(2)
   *   // returns Array(2, 3)
   * }}}
   *
   * @note This method should only be used if the resulting array is expected to be small, as
   * all the data is loaded into the driver's memory.
   *
   * @param num k, the number of elements to return
   * @param ord the implicit ordering for T
   * @return an array of top elements
   */
  def takeOrdered(num: Int)(implicit ord: Ordering[T]): Array[T] = withScope {
    if (num == 0) {
      Array.empty
    } else {
      val mapRDDs = mapPartitions { items =>
        // Priority keeps the largest elements, so let's reverse the ordering.
        val queue = new BoundedPriorityQueue[T](num)(ord.reverse)
        queue ++= collectionUtils.takeOrdered(items, num)(ord)
        Iterator.single(queue)
      }
      if (mapRDDs.partitions.length == 0) {
        Array.empty
      } else {
        mapRDDs.reduce { (queue1, queue2) =>
          queue1 ++= queue2
          queue1
        }.toArray.sorted(ord)
      }
    }
  }
```

* 案例

```
    val rdd = sc.makeRDD(List(1,4,3,2),2)
    val l: Long = rdd.count()
    println(l)

    val i1: Int = rdd.first()
    println(i1)

    val ints1: Array[Int] = rdd.take(3)
    println(ints1.mkString(","))

    // 【1，2，3】
    val ints2: Array[Int] = rdd.takeOrdered(3)
    println(ints2.mkString(","))
```

### 4.aggregate*

* 源码

```scala
  /**
   * Aggregate the elements of each partition, and then the results for all the partitions, using
   * given combine functions and a neutral "zero value". This function can return a different result
   * type, U, than the type of this RDD, T. Thus, we need one operation for merging a T into an U
   * and one operation for merging two U's, as in scala.TraversableOnce. Both of these functions are
   * allowed to modify and return their first argument instead of creating a new U to avoid memory
   * allocation.
   *
   * @param zeroValue the initial value for the accumulated result of each partition for the
   *                  `seqOp` operator, and also the initial value for the combine results from
   *                  different partitions for the `combOp` operator - this will typically be the
   *                  neutral element (e.g. `Nil` for list concatenation or `0` for summation)
   * @param seqOp an operator used to accumulate(积累) results within a partition
   * @param combOp an associative(结合) operator used to combine results from different partitions
   */
  def aggregate[U: ClassTag](zeroValue: U)(seqOp: (U, T) => U, combOp: (U, U) => U): U = withScope {
    // Clone the zero value since we will also be serializing it as part of tasks
    var jobResult = Utils.clone(zeroValue, sc.env.serializer.newInstance())
    val cleanSeqOp = sc.clean(seqOp)
    val cleanCombOp = sc.clean(combOp)
    val aggregatePartition = (it: Iterator[T]) => it.aggregate(zeroValue)(cleanSeqOp, cleanCombOp)
    val mergeResult = (_: Int, taskResult: U) => jobResult = combOp(jobResult, taskResult)
    sc.runJob(this, aggregatePartition, mergeResult)
    jobResult
  }
```

* 案例

```scala
aggregate执行计算时，初始值会参与分区内计算,也会参与分区间的计算
val conf: SparkConf = new SparkConf().setAppName("Spark").setMaster("local[*]")
val sc: SparkContext = new SparkContext(conf)
val rdd: RDD[Int] = sc.makeRDD(List(1, 2, 3, 4), 8)
rdd.mapPartitionsWithIndex(
    (index, datas) => {
       println("分区号：" + index + "-> 分区数据：" + datas.mkString(","))
       datas
}).collect()
val res: Int = rdd.aggregate(1)(_ + _, _ + _)
println(res)     
---------------------------------------------------
输出结果
分区号：4-> 分区数据：
分区号：2-> 分区数据：
分区号：1-> 分区数据：1
分区号：5-> 分区数据：3
分区号：7-> 分区数据：4
分区号：0-> 分区数据：
分区号：6-> 分区数据：
分区号：3-> 分区数据：2
19

```

### 5.fold*

* 源码

```
def fold(zeroValue: T)(op: (T, T) => T): T 
```

* 案例

```scala
fold 是aggregate的简化，分区内和分区间计算规则相同
val rdd = sc.makeRDD(List(1,4,3,2),2)
val j: Int = rdd.fold(5)(_ + _)
25
```

### 6.countbykey*

* 源码

```scala
  /**
   * Count the number of elements for each key, collecting the results to a local Map.
   *
   * @note This method should only be used if the resulting map is expected to be small, as
   * the whole thing is loaded into the driver's memory.
   * To handle very large results, consider using rdd.mapValues(_ => 1L).reduceByKey(_ + _), which
   * returns an RDD[T, Long] instead of a map.
   */
  def countByKey(): Map[K, Long] = self.withScope {
    self.mapValues(_ => 1L).reduceByKey(_ + _).collect().toMap
  }
```

* 案例

```scala
val rdd = sc.makeRDD(List(1,4,3,2),2)
// countByKey算子表示相同key出现的次数
val rdd1: RDD[(String, Int)] = rdd.map(("a", _))
val map: collection.Map[String, Long] = rdd1.countByKey()
println(map) Map(a->4)
```

### 7.countbyvalue*

* 源码

```scala
  /**
   * Return the count of each unique value in this RDD as a local map of (value, count) pairs.
   *
   * @note This method should only be used if the resulting map is expected to be small, as
   * the whole thing is loaded into the driver's memory.
   * To handle very large results, consider using
   *
   * {{{
   * rdd.map(x => (x, 1L)).reduceByKey(_ + _)
   * }}}
   *
   * , which returns an RDD[T, Long] instead of a map.
   */

  def countByValue()(implicit ord: Ordering[T] = null): Map[T, Long] = withScope {
  //参数value 指代整体的单值value,双值value 和kv键值对
    map(value => (value, null)).countByKey()
  }

```

### 8.闭包问题

```
// Scala语法 ： 闭包
1）Spark在执行算子时，如果算子的内部使用了外部的变量（对象），那么意味着一定会出现闭包
2）在这种场景中，需要将Driver端的变量通过网络传递给Executor端执行，这个操作不用执行也能判断出来
3）可以在真正执行之前，对数据进行序列化校验，
4）Spark在执行作业前，需要先进行闭包检测功能。
```



## 三.RDD类

### 1.MapPartitionsRDD

* 源码

```scala
/**
 * An RDD that applies the provided function to every partition of the parent RDD.
 *
 * @param prev the parent RDD.
 * @param f The function used to map a tuple of (TaskContext, partition index, input iterator) to
 * 			an output iterator.
 * @param preservesPartitioning Whether the input function preserves the partitioner, which should
 *                              be `false` unless `prev` is a pair RDD and the input function
 *                              doesn't modify the keys.
 */
private[spark] class MapPartitionsRDD[U: ClassTag, T: ClassTag](
    var prev: RDD[T],
    f: (TaskContext, Int, Iterator[T]) => Iterator[U],  // (TaskContext, partition index, iterator)
    preservesPartitioning: Boolean = false,)
  extends RDD[U](prev) {

  override val partitioner = if (preservesPartitioning) firstParent[T].partitioner else None

  override def getPartitions: Array[Partition] = firstParent[T].partitions

  override def compute(split: Partition, context: TaskContext): Iterator[U] =
    f(context, split.index, firstParent[T].iterator(split, context))

}

```

* 源码分析

```
1.extends RDD[U](prev) 
这里的prev其实指的就是我们的HadoopRDD，也也就是说HadoopRDD变成了这个MapPartitionsRDD的OneToOneDependency依赖。OneToOneDependency是窄依赖。
2.MapPartitionsRDD重写了父类RDD的partitioner、getPartitions和compute。
```

```scala
 // override方法主要调用父类RDD的firstParent方法
 /** Returns the first parent RDD */
  protected[spark] def firstParent[U: ClassTag]: RDD[U] = {
    dependencies.head.rdd.asInstanceOf[RDD[U]]
  }

```

### 2.ShuffledRDD

### 3.HadoopRDD

### 4.RDD

### 5.Partitioner

* 源码

```scala
  /**
1.选择分区器以用于多个RDD之间的CoGroup操作
2.如果设置了spark.default.Parlellelism，我们将使用SparkContext DefaultPariStism 作为默认分区号码的值，否则新生成的rdd中partition的个数取与其依赖的父rdd中partition个数的最大值。
3.如果此partitioner符合条件（RDDS中最大分区中的最大分区数量的分区数），或者具有高于或等于默认分区的分区编号 - 我们使用此分区。否则我们将使用具有默认分区编号的HASHPartitioner
4.除非spark.default.Parlellelism是设置的，分区数量将与最大上游RDD中的分区数相同(partition的个数为该参数的值)，否则，新生成的rdd中partition的个数取与其依赖的父rdd中partition个数的最大值,因为这应该是最不可能导致内存失效。
   */
  def defaultPartitioner(rdd: RDD[_], others: RDD[_]*): Partitioner = {
    val rdds = (Seq(rdd) ++ others)
    val hasPartitioner = rdds.filter(_.partitioner.exists(_.numPartitions > 0))

    val hasMaxPartitioner: Option[RDD[_]] = if (hasPartitioner.nonEmpty) {
      Some(hasPartitioner.maxBy(_.partitions.length))
    } else {
      None
    }
```

#### 1.HashPartitioner

* 源码

```scala
/**
[[org.apache.spark.Partitioner]] 实现 hash-based partitioning 使用了java Object.hashCode.
 *
 * Java arrays have hashCodes that are based on the arrays' identities rather than their contents,
 * so attempting to partition an RDD[Array[_]] or RDD[(Array[_], _)] using a HashPartitioner will
 * produce an unexpected or incorrect result.
 */
class HashPartitioner(partitions: Int) extends Partitioner {
  require(partitions >= 0, s"Number of partitions ($partitions) cannot be negative.")

  def numPartitions: Int = partitions

  def getPartition(key: Any): Int = key match {
    case null => 0
    //  继续进入nonNegativeMod源码得知 这是一个hashcode对numPartitions取模
    case _ => Utils.nonNegativeMod(key.hashCode, numPartitions)
  }

  override def equals(other: Any): Boolean = other match {
    case h: HashPartitioner =>
      h.numPartitions == numPartitions
    case _ =>
      false
  }

  override def hashCode: Int = numPartitions
}
def nonNegativeMod(x: Int, mod: Int): Int = {
    val rawMod = x % mod
    rawMod + (if (rawMod < 0) mod else 0)
  }
```

* 补充

```
HashPartitioner是一个基于Java的Object.hashCode实现的(物理地址+链表)基于hash的partitioner。由于Java arrays的Hash code是基于arrays的标识而不是它的内容，所以如果使用HashPartitioner对RDD[Array[_]]或者RDD[(Array[_],_)]进行partition可能会得到不正确的结果。也就是说，如果rdd中保存的数据类型是arrays，这个时候默认的HashPartitioner是不可用的，用户在调用reduceByKey时需要自行实现一个partitioner，否则方法会抛出异常

```

### 6.PairRDDFunctions