## Spark on Yarn

### 一.环境准备

| 软件  | 版本                          |
| ----- | ----------------------------- |
| spark | spark-3.0.0-bin-hadoop3.2.tgz |
| scala | 2.12                          |

### 二.搭建

#### 1.linux步骤

```
tar -zxvf spark-3.0.0-bin-hadoop3.2.tgz -C /opt/module
ln -s spark-3.0.0-bin-hadoop3.2 spark

```

#### 2.yarn配置文件修改

* yarn-site.xml, 并分发

```sql
<!--是否启动一个线程检查每个任务正使用的物理内存量，如果任务超出分配值，则直接将其杀掉，默认是true -->
<property>
     <name>yarn.nodemanager.pmem-check-enabled</name>
     <value>false</value>
</property>

<!--是否启动一个线程检查每个任务正使用的虚拟内存量，如果任务超出分配值，则直接将其杀掉，默认是true -->
<property>
     <name>yarn.nodemanager.vmem-check-enabled</name>
     <value>false</value>
</property>

```

#### 3.修改spark配置文件

* spark-env.sh

```
mv spark-env.sh.template spark-env.sh
vim spark-env.sh
	export JAVA_HOME=/opt/module/jdk1.8.0_212
	YARN_CONF_DIR=/opt/module/hadoop/etc/hadoop

```

#### 4.配置历史服务器

* spark-defaults.conf
* hadoop fs -mkdir /spark-log

```
spark.eventLog.enabled          true
spark.eventLog.dir               hdfs://mycluster:8020/spark-log
```

* spark-env.sh

```
export SPARK_HISTORY_OPTS="
-Dspark.history.ui.port=18080 
-Dspark.history.fs.logDirectory=hdfs://mycluster:8020/spark-log
-Dspark.history.retainedApplications=30"

```

```
参数1含义：WEB UI访问的端口号为18080
参数2含义：指定历史服务器日志存储路径
参数3含义：指定保存Application历史记录的个数，如果超过这个值，旧的应用程序信息将被删除，这个是内存中的应用数，而不是页面上显示的应用数。

```

* spark-defaults.conf

```
spark.yarn.historyServer.address=hadoop0:18080
spark.history.ui.port=18080

```

* 启动历史服务

```
sbin/start-history-server.sh 
```

* 提交应用测试

```
bin/spark-submit \
--class org.apache.spark.examples.SparkPi \
--master yarn \
--deploy-mode client \
./examples/jars/spark-examples_2.12-3.0.0.jar \
10
```

#### 5.启动hdfs.yarn集群

```
my_hadoop.sh  start  # 脚本启动
```

### 三.sumbit命令解释

```
1)	--class表示要执行程序的主类，此处可以更换为咱们自己写的应用程序
2)	--master local[2] 部署模式，默认为本地模式，数字表示分配的虚拟CPU核数量
3)	spark-examples_2.12-3.0.0.jar 运行的应用类所在的jar包，实际使用时，可以设定为咱们自己打的jar包
4)	数字10表示程序的入口参数，用于设定当前应用的任务数量
```

| 参数                     | 解释                                                         | 可选值举例                              |
| ------------------------ | ------------------------------------------------------------ | --------------------------------------- |
| -class                   | Spark程序中包含主函数的类                                    |                                         |
| --master                 | Spark程序运行的模式(环境)                                    | 模式local[*]、spark://linux1:7077、Yarn |
| --executor-memory 1G     | 指定每个executor可用内存为1G	符合集群内存配置即可         |                                         |
| --total-executor-cores 2 | 指定所有executor使用的cpu核数为2个                           |                                         |
| --executor-cores         | 指定每个executor使用的cpu核数                                |                                         |
| –deploy-mode             | driver运行的模式，client或者cluster模式，默认为client        |                                         |
| application-jar          | 打包好的应用jar，包含依赖。这个URL在集群中全局可见。 比如hdfs:// 共享存储系统，如果是file:// path，那么所有的节点的path都包含同样的jar |                                         |
| application-arguments    | 传给main()方法的参数                                         |                                         |

### 四.端口

```
	Spark查看当前Spark-shell运行任务情况端口号：4040（计算）
	Spark Master内部通信服务端口号：7077
	Standalone模式下，Spark Master Web端口号：8080（资源）
	Spark历史服务器端口号：18080
	Hadoop YARN任务运行情况查看端口号：8088

```

