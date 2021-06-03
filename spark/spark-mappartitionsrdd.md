## 一.Transformation



| 条目      | 解释                          |
| --------- | ----------------------------- |
| h3标题有* | 产生shuffle落盘操作           |
| h3标题有$ | 预聚合操作                    |
| !         | 需要Todo                      |
| &         | 只能作用PairRDD(kv形式键值对) |



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

### 7.filter

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

### 8.sample

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

### 9.distinct

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

### 10.reducebyKey*$!

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

```
    val dataRDD1 = sc.makeRDD(List(("a",1),("a",2),("c",3),("d",1),("e",2),("c",2)))
//    dataRDD1.saveAsTextFile("output")
//    val dataRDD2 = dataRDD1.reduceByKey(_+_).collect().foreach(println(_))
    val dataRDD3 = dataRDD1.reduceByKey(_+_,2)
    dataRDD3.saveAsTextFile("output")
    dataRDD3.collect().foreach(println(_))
```

### 11.coalesce*

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

### 12.repartition*

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

### 13.sortby*

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

### 14.partitionby*&

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



## 二.RDD类

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

### 2.ShuffleRDD

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

