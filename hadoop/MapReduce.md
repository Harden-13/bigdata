## <span style='color:yellow'>Map Reduce</span>

### <span style='color:red'>1.map reduce总概</span>

#### 1.MR缺点

```
1）不擅长实时计算
MapReduce无法像MySQL一样，在毫秒或者秒级内返回结果
2）不擅长流式计算
流式计算的输入数据是动态的，而MapReduce的输入数据集是静态的，不能动态变化。
3）不擅长DAG（有向无环图）计算
多个应用程序存在依赖关系，后一个应用程序的输入为前一个的输出。在这种情况下，MapReduce并不是不能做，而是使用后，每个MapReduce作业的输出结果都会写入到磁盘，会造成大量的磁盘IO，导致性能非常的低下。

```

#### 2.MR核心思想

```
（1）分布式的运算程序往往需要分成至少2个阶段。
（2）第一个阶段的MapTask并发实例，完全并行运行，互不相干。
（3）第二个阶段的ReduceTask并发实例互不相干，但是他们的数据依赖于上一个阶段的所有MapTask并发实例的输出。
（4）MapReduce编程模型只能包含一个Map阶段和一个Reduce阶段，如果用户的业务逻辑非常复杂，那就只能多个MapReduce程序，串行运行。
```

#### 3.MR进程

```
（1）MrAppMaster：负责整个程序的过程调度及状态协调。
（2）MapTask：负责Map阶段的整个数据处理流程。
（3）ReduceTask：负责Reduce阶段的整个数据处理流程
```

#### 4.常见的数据序列化类型

```
Java类型	   Hadoop Writable类型
Boolean		BooleanWritable
Byte		ByteWritable
Int			IntWritable
Float		FloatWritable
Long		LongWritable
Double		DoubleWritable
String		Text
Map			MapWritable
Array		ArrayWritable
Null		NullWritable

```

#### 5.编程规范

* Mapper阶段

```
1.用户自定义mapper要继承自己的父类
2.mapper的输入数据是kv对的形式
3.mapper业务逻辑卸载map（）中
4.mapper的输出数据是kv对
5.map方法（maptask进程）对每一个<k,v>调用一次
```

* Reducer阶段

```
1.用户自定义Reducerr要继承自己的父类
2.Reducer的输入数据类型对应Mapper的输出数据类型，也就是kv
3.Reducer业务逻辑卸载Reducer（）中
4.Reducer方法（Reducertask进程）对每一个<k,v>调用一次
```

* Driver阶段

```
相当于Yar集群客户端，用于提交我们整个程序到yarn集群，提交的是封装了mapreduce程序相关参数的job对象
```

### 2.序列化Writable接口

```
Hadoop序列化的作用
序列化在分布式环境的两大作用：进程间通信，永久存储(对象的传递)。
Hadoop节点间通信。
```

* examples 序列化在mr中应用

```
需求分析：统计手机上行下行使用流量（k:FlowBean(upFlow,downFlow,sumFlow)）
```

```
public class FlowCountMapper extends Mapper<LongWritable, Text,Text,FlowBean> {
    Text text = new Text();
    FlowBean flowBean = new FlowBean();
    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
        String[] split = value.toString().split("\t");
        String phone = split[1];
        Long upFlow = Long.parseLong(split[split.length-3]);
        Long downFlow = Long.parseLong(split[split.length-2]);
        text.set(phone);
        flowBean.setUpFlow(upFlow);
        flowBean.setDownFlow(downFlow);
        context.write(text,flowBean);
    }
}
```

```
public class FlowCountReducer  extends Reducer<Text,FlowBean,Text,FlowBean> {
    @Override
    protected void reduce(Text key, Iterable<FlowBean> values, Context context) throws IOException, InterruptedException {
        long sumUpFlow=0;
        long sumDownFlow=0;

        for(FlowBean flowBean:values){
            sumUpFlow+=flowBean.getUpFlow();
            sumDownFlow+=flowBean.getDownFlow();
        }
        FlowBean flowBean = new FlowBean(sumUpFlow,sumDownFlow);
        context.write(key,flowBean);
    }
}
```

```
public class FlowBean implements Writable {
    private long upFlow;
    private long downFlow;
    private long sumFlow;

    public FlowBean() {
        super();
    }
    public FlowBean(long upFlow, long downFlow){
        super();
        this.downFlow=downFlow;
        this.upFlow=upFlow;
        this.sumFlow = upFlow + downFlow;
    }
    public void write(DataOutput out) throws IOException {
        out.writeLong(upFlow);
        out.writeLong(downFlow);
        out.writeLong(sumFlow);
    }
    public void readFields(DataInput in) throws IOException {
        this.upFlow  = in.readLong();
        this.downFlow = in.readLong();
        this.sumFlow = in.readLong();
    }
```

### 3.框架原理

#### 1.切片与切块

```
数据块：Block是HDFS物理上把数据分成一块一块。数据块是HDFS存储数据单位。
数据切片：数据切片只是在逻辑上对输入进行分片，并不会在磁盘上将其切分成片进行存储。数据切片是MapReduce程序计算输入数据的单位，一个切片会对应启动一个MapTask。
① 切片的概念：从文件的逻辑上的进行大小的切分，一个切片多大，
		    将来一个MapTask的处理的数据就多大。
② 一个切片就会产生一个MapTask
③ 切片时只考虑文件本身，不考虑数据的整体集。
④ 切片大小和切块大小默认是一致的，这样设计目的为了避免将来切片读取数据的时候有跨机器的情况
```

#### 2.mapreduce数据流

```
Input->InputFormat->Mapper->Mapper sort->Shuffle->Copy Sort Reduce->Reducer->OutputFormat->Output
```

#### 3.InputFormat抽象类，二个抽象方法

```
public abstract class InputFormat<K, V>
  //负责切片
  public abstract List<InputSplit> getSplits
  //按行读取
  public abstract RecordReader<K,V> createRecordReader
```

##### 1.FileInputFormat继承InputFormat

```
public abstract class FileInputFormat<K, V> extends InputFormat<K, V>
//具体实现切片
public List<InputSplit> getSplits(JobContext job)
 // 判断当前的文件的剩余内容是否要继续切片 SPLIT_SLOP = 1.1
				  // 判断公式：bytesRemaining)/splitSize > SPLIT_SLOP
				  // 用文件的剩余大小/切片大小 > 1.1 才继续切片（这样做的目的是为了让我们每一个MapTask处理的数据更加均衡）
				  while (((double) bytesRemaining)/splitSize > SPLIT_SLOP) {
					int blkIndex = getBlockIndex(blkLocations, length-bytesRemaining);
					splits.add(makeSplit(path, length-bytesRemaining, splitSize,
								blkLocations[blkIndex].getHosts(),
								blkLocations[blkIndex].getCachedHosts()));
					bytesRemaining -= splitSize;
				  }
```

###### 1.切片原理

```
1.程序先找到数据存储的目录
2.开始遍历处理（规划切片）目录下的每一个文件
3.遍历第一个文件
	获取文件大小fs.size()
	计算切片大小computeSplitSize(blockSize, minSize, maxSize)=128M
	开始切片0：128M;128M:256M;256M:300M
	每次切片时候判断当前的文件的剩余内容是否要继续切片 SPLIT_SLOP = 1.1
	将切片信息写入到一个文件中
	整个切片核心在getSplit()方法中
4.切片规划文件到Yarn上，Yarn上的MRappmaster根据切片规划文件计算开启MT个数
5.切片时不考虑数据集整体，二十逐个对每一个文件进行单独切片
	a:300M 0-128M;128-256M;256-300M;
	b:60M  0-60M
```

###### 2.TextInputFormat

```
public class TextInputFormat extends FileInputFormat<LongWritable, Text>
  public RecordReader<LongWritable, Text> 
    createRecordReader(InputSplit split,
                       TaskAttemptContext context)
    //返回按行读取       
    return new LineRecordReader(recordDelimiterBytes);
```

##### 2.CombineTextInputFormat切片机制

* 应用场景
  * CombineTextInputFormat用于小文件过多的场景，它可以将多个小文件从逻辑上规划到一个切片中，这样，多个小文件就可以交给一个MapTask处理。

```
public abstract class CombineFileInputFormat<K, V>
  extends FileInputFormat<K, V>
public class CombineTextInputFormat
  extends CombineFileInputFormat<LongWritable,Text>  
```

* 虚拟存储切片最大值设置

```
CombineTextInputFormat.setMaxInputSplitSize(job, 4194304);// 4m

注意：虚拟存储切片最大值设置最好根据实际的小文件大小情况来设置具体的值
```

* **切片机制**

  生成切片过程包括：虚拟存储过程和切片过程二部分

```
（1）虚拟存储过程：
将输入目录下所有文件大小，依次和设置的setMaxInputSplitSize值比较，如果不大于设置的最大值，逻辑上划分一个块。如果输入文件大于设置的最大值且大于两倍，那么以最大值切割一块；当剩余数据大小超过设置的最大值且不大于最大值2倍，此时将文件均分成2个虚拟存储块（防止出现太小切片）。
例如setMaxInputSplitSize值为4M，输入文件大小为8.02M，则先逻辑上分成一个4M。剩余的大小为4.02M，如果按照4M逻辑划分，就会出现0.02M的小的虚拟存储文件，所以将剩余的4.02M文件切分成（2.01M和2.01M）两个文件。
（2）切片过程：
（a）判断虚拟存储的文件大小是否大于setMaxInputSplitSize值，大于等于则单独形成一个切片。
（b）如果不大于则跟下一个虚拟存储文件进行合并，共同形成一个切片。
（c）测试举例：有4个小文件大小分别为1.7M、5.1M、3.4M以及6.8M这四个小文件，则虚拟存储之后形成6个文件块，大小分别为：
1.7M，（2.55M、2.55M），3.4M以及（3.4M、3.4M）
最终会形成3个切片，大小分别为：
（1.7+2.55）M，（2.55+3.4）M，（3.4+3.4）M

```

#### 4.Shuffle工作流程

```
按照行读取，分片->MT->kv对-缓冲区——>shuffle，，，——>落地文件

具体Shuffle过程详解，如下：
（1）MapTask收集我们的map()方法输出的kv对，放到内存缓冲区中
（2）从内存缓冲区不断溢出本地磁盘文件，可能会溢出多个文件
（3）多个溢出文件会被合并成大的溢出文件
（4）在溢出过程及合并的过程中，都要调用Partitioner进行分区和针对key进行排序
（5）ReduceTask根据自己的分区号，去各个MapTask机器上取相应的结果分区数据
（6）ReduceTask会抓取到同一个分区的来自不同MapTask的结果文件，ReduceTask会将这些文件再进行合并（归并排序）
（7）合并成大文件后，Shuffle的过程也就结束了，后面进入ReduceTask的逻辑运算过程（从文件中取出一个一个的键值对Group，调用用户自定义的reduce()方法）
注意：
（1）Shuffle中的缓冲区大小会影响到MapReduce程序的执行效率，原则上说，缓冲区越大，磁盘io的次数越少，执行速度就越快。
（2）缓冲区的大小可以通过参数调整，参数：mapreduce.task.io.sort.mb默认100M。
（3）源码解析流程

```

#### 5.分区源码

* hadoop-mapreduce-client-core-3.1.3.jar

```
public abstract class Partitioner<KEY, VALUE>
```

```
public class HashPartitioner<K, V> extends Partitioner<K, V>
   //默认分区是key.hascode对rt个数取模。用户无法控制
   public int getPartition(K key, V value,
                          int numReduceTasks) {
    return (key.hashCode() & Integer.MAX_VALUE) % numReduceTasks;
  }
```

#### 6.排序

```
MT&RT均会对数据按照key进行排序，该操作属于Hadoop默认行为
默认排序是按照字典的顺序排序，实现排序的方法是快速排序
```

* 排序概述

```
MT它会将处理的结果暂时放到环形缓冲区中，当环形缓冲区使用率达到一定阈值后，在对缓冲区中的数据进行一次快排，并将这些有序的数据溢写到磁盘上，而当数据处理完成后，它会对磁盘上的所有文件进行归并排序
RT它从每个mt上远程copy相应的数据文件，如果文件大小达到一定阈值，溢写到磁盘上否则存储在内存中，如果磁盘上文件数目达到一定阈值则进行一次归并排序生成更大的一个文件，如果内存中文件大小或者数目超过一定阈值，进行一次合并后将数据溢写到磁盘上，当所有的数据完成copy后，RT统一对内存和磁盘上所有数据进行一次归并排序
```

* 排序分类

```
1.部分排序
MR根据输入记录键值对数据集排序，输出的每个文件内部有序
2.全排序
最终输出结果只有一个文件，内部有序，效率低
3.辅助排序：Redcue端对key进行分组，在接受key为bean对象时，想让一个或者几个字段相同key进入同一个reduce方法
4.2次排序，compareTo判断条件2个即为2次排序
```

#### 7.MT工作机制

```
（1）Read阶段：MapTask通过InputFormat获得的RecordReader，从输入InputSplit中解析出一个个key/value。
	（2）Map阶段：该节点主要是将解析出的key/value交给用户编写map()函数处理，并产生一系列新的key/value。
	（3）Collect收集阶段：在用户编写map()函数中，当数据处理完成后，一般会调用OutputCollector.collect()输出结果。在该函数内部，它会将生成的key/value分区（调用Partitioner），并写入一个环形内存缓冲区中。
	（4）Spill阶段：即“溢写”，当环形缓冲区满后，MapReduce会将数据写到本地磁盘上，生成一个临时文件。需要注意的是，将数据写入本地磁盘之前，先要对数据进行一次本地排序，并在必要时对数据进行合并、压缩等操作。
	溢写阶段详情：
	步骤1：利用快速排序算法对缓存区内的数据进行排序，排序方式是，先按照分区编号Partition进行排序，然后按照key进行排序。这样，经过排序后，数据以分区为单位聚集在一起，且同一分区内所有数据按照key有序。
	步骤2：按照分区编号由小到大依次将每个分区中的数据写入任务工作目录下的临时文件output/spillN.out（N表示当前溢写次数）中。如果用户设置了Combiner，则写入文件之前，对每个分区中的数据进行一次聚集操作。
	步骤3：将分区数据的元信息写到内存索引数据结构SpillRecord中，其中每个分区的元信息包括在临时文件中的偏移量、压缩前数据大小和压缩后数据大小。如果当前内存索引大小超过1MB，则将内存索引写到文件output/spillN.out.index中。
	（5）Merge阶段：当所有数据处理完成后，MapTask对所有临时文件进行一次合并，以确保最终只会生成一个数据文件。
	当所有数据处理完后，MapTask会将所有临时文件合并成一个大文件，并保存到文件output/file.out中，同时生成相应的索引文件output/file.out.index。
	在进行文件合并过程中，MapTask以分区为单位进行合并。对于某个分区，它将采用多轮递归合并的方式。每轮合并mapreduce.task.io.sort.factor（默认10）个文件，并将产生的文件重新加入待合并列表中，对文件排序后，重复以上过程，直到最终得到一个大文件。
	让每个MapTask最终只生成一个数据文件，可避免同时打开大量文件和同时读取大量小文件产生的随机读取带来的开销。

```

#### 8.RT工作机制

```
（1）Copy阶段：ReduceTask从各个MapTask上远程拷贝一片数据，并针对某一片数据，如果其大小超过一定阈值，则写到磁盘上，否则直接放到内存中。（要按行输出所以需要把copy过来的文件优先放在内存中）
	（2）Merge阶段：在远程拷贝数据的同时，ReduceTask启动了两个后台线程对内存和磁盘上的文件进行合并，以防止内存使用过多或磁盘上文件过多。
	（3）Sort阶段：按照MapReduce语义，用户编写reduce()函数输入数据是按key进行聚集的一组数据。为了将key相同的数据聚在一起，Hadoop采用了基于排序的策略。由于各个MapTask已经实现对自己的处理结果进行了局部排序，因此，ReduceTask只需对所有数据进行一次归并排序即可。
	（4）Reduce阶段：reduce()函数将计算结果写到HDFS上
-

```

* **设置ReduceTask**并行度（个数）

```
ReduceTask的并行度同样影响整个Job的执行并发度和执行效率，但与MapTask的并发数由切片数决定不同，ReduceTask数量的决定是可以直接手动设置，也可以是通过分区数决定RT：

// 默认值是1，手动设置为4

job.setNumReduceTasks(4);

```

* RT个数问题

```
MapReduce中输出文件的个数与Reduce的个数一致，默认情况下有一个Reduce，输出只有一个文件，文件名为part-r-00000，文件内容的行数与map输出中不同key的个数一致。如果有两个Reduce，输出的结果就有两个文件，第一个为part-r-00000，第二个为part-r-00001，依次类推。
```

### 4.OutPutFormat是MR输出基类

##### 1.常见OutPutFormat实现类

```
1.TextOutPutFormat,它把每条记录记录为文本行，因为TextOutPutFormat调用toString()方法把它们转换为字符串
2.SequenceFIleOutPutFormat，将它的输出作为后续MR任务的输入，因为格式紧凑，很容易被压缩
3.自定义OutPutFormat,根据用户需求，自定义实现输出
```

##### 2.使用场景

```
1.控制最终文件的输出路径和输出格式，可以自定义OutPUtFormat
2.自定义步骤，自定义一个类继承FileOutPutFormat，改写RecordWriter,具体改写输出的write方法
```

##### 3 实现类

* OutPutFormat接口定义

```
public interface OutputFormat<K, V>
//Get the {@link RecordWriter} for the given job.
  RecordWriter<K, V> getRecordWriter
//Check for validity of the output-specification for the job.
  void checkOutputSpecs(FileSystem ignored, JobConf job)
```

* FileOutPutFormat抽象类的体系结构， checkOutputSpecs() 做了具体的实现

```
    // Ensure that the output directory is set and not already there
    Path outDir = getOutputPath(job);
    if (outDir == null && job.getNumReduceTasks() != 0) {
      throw new InvalidJobConfException("Output directory not set in JobConf.");
    }     
      // check its existence
      if (fs.exists(outDir)) {
        throw new FileAlreadyExistsException("Output directory " + outDir + 
                                             " already exists");
      }
```

* TextOutPutFormat是MR中默认实现输出功能的类它主要用来将文本数据输出到HDFS上。

```
public class TextOutputFormat<K, V> extends FileOutputFormat<K, V>
  public RecordWriter<K, V> getRecordWriter
//按行写出  
    return new LineRecordWriter<K, V>
```



### 5.Join多种应用

###### 1.Reduce Join

* Reduce Join原理

```
1.Map端主要工作
为来自不同表或者文件的key/value对，打标签区别不同来源的记录，然后用连接的字段作为key，其余部分和新加的标志作为value，最后进行输出
2.Reduce端的主要工作，在Reduce端以连接字段作为key的分组已经完成，我们只需要在每一个分组当中将那些来源于不同文件的记录（map阶段以仅打标签）分开，最后进行合并就ok
3.以key作为排序，如果key数据类型为可排序的直接参考排序
```

* 缺点

```
合并的操作实在reduce阶段完成，reduce端处理压力太大，map节点运算负载很低，资源利用率不高，且在reduce阶段记忆产生数据倾斜
```

###### 2.Map Join

* 使用场景

```
MapJoin适用于一张表很大，另外一张表很小
在map端缓存多张数据表，提前处理业务逻辑。这样增加map端业务。减少Reduce端数局压力
```

### 6 .Job源码分析

* instance.waitForCompletion跟踪这个函数执行过程

```
public boolean waitForCompletion
//  public enum JobState {DEFINE, RUNNING};
    if (state == JobState.DEFINE) 
//进入sumbit函数
      submit();
```

* sumbit()-->return submitter.submitJobInternal(Job.this, cluster);

```
JobStatus submitJobInternal(Job job, Cluster cluster) 
//validate the jobs output specs 
    checkSpecs(job);
//实现的逻辑
//检测输入输出路径的合法性
//给当前Job计算切片信息
//添加分布式缓存文件， 将必要的内容都拷贝到 job执行的临时目录（jar包、切片信息、配置文件）(执行的jar包copy到集群中/tmp/hadoop/staging.../application_id/,还会生成job.xml配置文件里面包括了hadoop默认配置文件和自己配置的)
//提交Job
```

* checkSpecs函数

```
output.checkOutputSpecs(job);
//OutputFormat的抽象方法，由FileOutPutFormat实现了checkOutputSpecs检查output-specification的逻辑

```

## 备注

```
将程序打成jar包，然后拷贝到Hadoop集群中
hadoop jar  wc.jar
 com.mrtest.wordcount.WordcountDriver /user/hadoop/input /user/hadoop/output

```



