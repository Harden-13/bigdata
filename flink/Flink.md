# Flink

## 一.Flink简介

### 1.Flink优势

| 关键字                                             | 描述                                                         |
| -------------------------------------------------- | ------------------------------------------------------------ |
| 事件时间（event-time）和处理时间（processing-tme） | 即使对于无序事件流，事件时间（event-time）语义仍然能提供一致且准确的结果。而处理时间（processing-time）语义可用于具有极低延迟要求的应用程序。 |
| 状态一致性                                         | 精确一次（exactly-once）的状态一致性保证                     |
| 毫秒级延迟                                         | 每秒处理数百万个事件。Flink 应用程序可以扩展为在数千个核（cores）上运行 |
| 分层 API                                           | SQL-->Table API-->DataStream / DataSet API-->Stateful Stream Processing |
|  连接到最常用的存储系统                             | Apache Kafka，Apache Cassandra，Elasticsearch，JDBC，Kinesis 和（分布式）文件系统，如 HDFS 和 S3 |
|  无单点故障                                         | 与 Kubernetes，YARN 和 Apache Mesos的紧密集成，再加上从故障中快速恢复和动态扩展任务的能力，Flink 能够以极少的停机时间 7*24 全天候运行流应用程序。 |





### 2.spark对比

| 序号     | Flink                                                        | Spark                                                        |
| -------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 处理方式 | 流式                                                         | 流批一体                                                     |
| 数据模型 | Flink 基本数据模型是数据流，以及事件（Event）序列（Integer、String、Long、POJO Class） | Spark 采用 RDD 模型，Spark Streaming 的 DStream 实际上也就是一组组小批数据 RDD 的集合 |
| 运行架构 | Flink 是标准的流执行模式，一个事件在一个节点处理完后可以直接发往下一个节点进行处理 | • Spark 是批计算，将 DAG 划分为不同的 Stage，一个 Stage完成后才可以计算下一个 Stage |

### 3.flink流

| 有界流                                                       | 无界流                                                       |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| 离线数据                                                     | 实时数据                                                     |
| 定义流的开始，也有定义流的结束                               | 有定义流的开始，但没有定义流的结束                           |
| 处理无界数据通常要求以特定顺序摄取事件，例如事件发生的顺序，以便能够推断结果的完整性。 | 有界流可以在摄取所有数据后再进行计算。有界流所有数据可以被排序，所以并不需要有序摄取。有界流处理通常被称为批处理 |
|                                                              |                                                              |

## 二.Flink架构

### 1.master-slave

|      | Jobmanager | Taskmanager |
| ---- | ---------- | ----------- |
| 数量 | 1个        | n个         |

### 2.Jobmanager

| JobManager                            | 描述                                                         |
| ------------------------------------- | ------------------------------------------------------------ |
| 控制程序执行的主进程                  | 每个应用程序都会被一个不同的 JobManager 所控制执行。         |
| 接收到要执行的程序                    | 这个应用程序会包括：作业图 (JobGraph)、逻辑数据流图和打包了所有的类、库和其它资源的 JAR 包。 |
| 把作业图转换物理层面数据流图          | 这个图被叫做“执行图”(ExecutionGraph)，包含了所有可以并发执行的任务。 |
| JM向Flink资源管理器请求执行任务的资源 | 也就是任务管理器 (TaskManager) 上的任务插槽（slot）。一旦它获取到了足够的资源，就会将执行图 (DAG) 分发到真正运行它们的 TaskManager 上。而在运行过程中，JobManager 会负责所有需要中央协调的操作，比如说检查点 (checkpoints) 的协调 |
| 资源管理器 (ResourceManager)：        | 负责Flink 集群中的资源提供、回收、分配 - 它管理 task slots，这是 Flink 集群中资源调度的单位。Flink 为不同的环境和资源提供者（例如 YARN、Mesos、Kubernetes 和 standalone部署）实现了对应的 ResourceManager。在 standalone 设置中，ResourceManager 只能分配可用 TaskManager 的 slots，而不能自行启动新的 TaskManager。 |
| 分发器 (Dispatcher)                   | Dispatcher 提供了一个 REST 接口，<br/>用来提交 Flink 应用程序执行，并为每个提交的作业启动一个新的 JobMaster。它还运行 Flink WebUI 用来提供作业执行信息 |
| JobMaster：                           | 负责管理单个 JobGraph 的执行。Flink 集群中可以同时运行多个作业，每个作业都有自己的JobMaster。 |
|                                       |                                                              |

### 3.resourcemanager

| resourcemanager | 描述                                                         |
| --------------- | ------------------------------------------------------------ |
| 1               | 负责管理任务管理器（TaskManager）的插槽（slot），TaskManager 插槽是 Flink 中定义的处理资源单元 |
| 2               | JobManager 申请插槽资源时，Flink 的资源管理器会将有空闲插槽的 TaskManager 分配给 JobManager。如果 Flink的资源管理器没有足够的插槽来满足 JobManager 的请求，它还以向 Yarn 的资源管理器发起会话，以提供启动TaskManager 进程的容器。 |
|                 |                                                              |

### 3.dispatcher

|      |                                                              |
| ---- | ------------------------------------------------------------ |
| 1    | 可以跨作业运行，它为应用提交提供了 RESTful 接口(GET/PUT/DELETE/POST)。 |
| 2    | 当一个应用被提交执行时，分发器就会启动并将应用移交给一个 JobManager。 |
| 3    | Dispatcher 也会启动一个 Web UI(localhost:8081)，用来方便地展示和监控作业执行的信息 |
| 4    | Dispatcher 在架构中可能并不是必需的，这取决于应用提交运行的方式。 |
|      |                                                              |

### 4.TaskManager

| 序号 | TaskManager                                                  | Slot                                                         |
| ---- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 1    | 每一个 TaskManager 都是一个 JVM 进程                         | 每一个任务插槽都会启动一个线程                               |
| 2    | 控制一个 TaskManager 能接收多少个 task，TaskManager 通过 task slot 来进行控制（一个 TaskManager至少有一个 slot） | 它可能会在独立的线程上执行一个或多个 subtask，每一个子任务占用一个任务插槽（Task Slot） |
| 3    |                                                              | Flink 允许子任务共享 slot,一个 slot 可以保存作业的整个管道   |
| 4    |                                                              | Task Slot 是静态的概念，是指 TaskManager 具有的并发执行能力  |

