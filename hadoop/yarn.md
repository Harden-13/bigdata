### **Yarn**

#### 1.Yarn架构

* 主要由ResourceManager、NodeManager、ApplicationMaster和Container等组件构成。
* ResourceManager(RM)主要功能
  * 处理客户端请求
  * 监控nm
  * 启动或者监控applicationmaster
  * 资源分配与管理
* NodeManager(nm)主要作用
  * 管理单个节点资源
  * 处理来自rm的命令
  * 处理来自applicationmaster命令
* applicationMaster(am)作用如下
  * 负责数据的切分
  * 为应用程序申请资源，并且分配给内部的任务
  * 任务的监控与容错
* container
  * yarn中的资源抽象，它封装了某个节点上的多维度资源，内存 cpu等等

#### 2.Yarn工作机制

* yarn提交过程全详解

```
（1）MR程序提交到客户端所在的节点。
	/opt/wc.jar;job.waitForConnection()
（2）YarnRunner向ResourceManager申请一个Application。
（3）RM将该应用程序的资源路径返回给YarnRunner。
（4）该程序将运行所需资源提交到HDFS上。
		hdfs://tmp/hadoop/staging/.../application_id
		job.split
		job.xml
		wc.jar
（5）程序资源提交完毕后，申请运行mrAppMaster。
（6）RM将用户的请求初始化成一个Task。
（7）其中一个NodeManager领取到Task任务。
（8）该NodeManager创建容器Container，并产生MRAppmaster(相当于mt,mr任务总控)。
（9）Container从HDFS上拷贝资源到本地。
（10）MRAppmaster向RM 申请运行MapTask资源。
（11）RM将运行MapTask任务分配给另外两个NodeManager，另两个NodeManager分别领取任务并创建容器。
（12）MR向两个接收到任务的NodeManager发送程序启动脚本，这两个NodeManager分别启动MapTask，MapTask对数据分区排序。
（13）MrAppMaster等待所有MapTask运行完毕后，向RM申请容器，运行ReduceTask。
（14）ReduceTask向MapTask获取相应分区的数据。
（15）程序运行完毕后，MR会向RM申请注销自己

```

* 进度状态更新

```
进度和状态更新
YARN中的任务将其进度和状态(包括counter)返回给应用管理器, 客户端每秒(通过mapreduce.client.progressmonitor.pollinterval设置)向应用管理器请求进度更新, 展示给用户。
作业完成
除了向应用管理器请求作业进度外, 客户端每5秒都会通过调用waitForCompletion()来检查作业是否完成。时间间隔可以通过mapreduce.client.completion.pollinterval来设置。作业完成之后, 应用管理器和Container会清理工作状态。作业的信息会被作业历史服务器存储以备之后用户核查。

```

#### 3.资源调度器

```
Hadoop作业调度器主要有三种：FIFO、Capacity Scheduler和Fair Scheduler。Hadoop3.1.3默认的资源调度器是Capacity Scheduler。
```

* Capacity Scheduler 主要有以下几个特点

```
①容量保证。管理员可为每个队列设置资源最低保证和资源使用上限，而所有提交到该队列的应用程序共享这些资源。
②灵活性，如果一个队列中的资源有剩余，可以暂时共享给那些需要资源的队列，而一旦该队列有新的应用程序提交，则其他队列借调的资源会归还给该队列。这种资源灵活分配的方式可明显提高资源利用率。
③多重租赁。支持多用户共享集群和多应用程序同时运行。为防止单个应用程序、用户或者队列独占集群中的资源，管理员可为之增加多重约束（比如单个应用程序同时运行的任务数等）。
④安全保证。每个队列有严格的ACL列表规定它的访问用户，每个用户可指定哪些用户允许查看自己应用程序的运行状态或者控制应用程序（比如杀死应用程序）。此外，管理员可指定队列管理员和集群系统管理员。
⑤动态更新配置文件。管理员可根据需要动态修改各种配置参数，以实现在线集群管理。

```

