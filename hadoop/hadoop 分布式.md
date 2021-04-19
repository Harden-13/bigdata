#### hadoop 分布式

##### 1.环境基础

```
1.关闭防火墙，静态ip，主机状态，新建hadoop用户
2.安装jdk（1.8.0_212），hadoop(3.1.3)
3.配置java,hadoop环境变量
4.ssh免密钥登录
5.配置集群
6.群起集群并测试
```

#####  2.配制集群

* core-site.xml核心文件配置

```
<configuration>
	<!-- 指定NameNode的地址 -->
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://hadoop0:9820</value>
	</property>
<!-- 指定hadoop数据的存储目录 -->
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/opt/module/hadoop-3.1.3/data</value>
	</property>

<!-- 配置HDFS网页登录使用的静态用户为hadoop -->
    <property>
        <name>hadoop.http.staticuser.user</name>
        <value>hadoop</value>
	</property>

<!-- 配置该hadoop(superUser)允许通过代理访问的主机节点 -->
    <property>
        <name>hadoop.proxyuser.hadoop.hosts</name>
        <value>*</value>
	</property>
<!-- 配置该hadoop(superUser)允许通过代理用户所属组 -->
    <property>
        <name>hadoop.proxyuser.hadoop.groups</name>
        <value>*</value>
	</property>
<!-- 配置该hadoop(superUser)允许通过代理的用户-->
    <property>
        <name>hadoop.proxyuser.hadoop.groups</name>
        <value>*</value>
	</property>
</configuration>

```

* hdfs-site.xml ,hdfs配置文件

```
<configuration>
	<!-- nn web端访问地址-->
	<property>
        <name>dfs.namenode.http-address</name>
        <value>hadoop1:9870</value>
    </property>
	<!-- 2nn web端访问地址-->
    <property>
        <name>dfs.namenode.secondary.http-address</name>
        <value>hadoop2:9868</value>
    </property>
</configuration>

```

* yarn-site.xml配置文件

```
<configuration>
	<!-- 指定MR走shuffle -->
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
</property>
<!-- 指定ResourceManager的地址-->
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>hadoop1</value>
</property>
<!-- 环境变量的继承 -->
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>
</property>
<!-- yarn容器允许分配的最大最小内存 -->
    <property>
        <name>yarn.scheduler.minimum-allocation-mb</name>
        <value>512</value>
    </property>
    <property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>4096</value>
</property>
<!-- yarn容器允许管理的物理内存大小 -->
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>4096</value>
</property>
<!-- 关闭yarn对物理内存和虚拟内存的限制检查 -->
    <property>
        <name>yarn.nodemanager.pmem-check-enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>false</value>
    </property>
<Font color=Red><!--补充内容--></Font>
<!-- 开启日志聚集功能 -->
<property>
    <name>yarn.log-aggregation-enable</name>
    <value>true</value>
</property>
<!-- 设置日志聚集服务器地址 -->
<property>  
    <name>yarn.log.server.url</name>  
    <value>http://hadoop0:19888/jobhistory/logs</value>
</property>
<!-- 设置日志保留时间为7天 -->
<property>
    <name>yarn.log-aggregation.retain-seconds</name>
    <value>604800</value>
</property>
</configuration>

```

* mapred-site.xml,mapreduce配置文件

```
<configuration>
	<!-- 指定MapReduce程序运行在Yarn上 -->
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
</configuration>
<Font color=Red><!--补充内容--></Font>
<!-- 历史服务器端地址 -->
<property>
    <name>mapreduce.jobhistory.address</name>
    <value>hadoop0:10020</value>
</property>

<!-- 历史服务器web端地址 -->
<property>
    <name>mapreduce.jobhistory.webapp.address</name>
    <value>hadoop0:19888</value>
</property>

```

* workers文件配置

```
hadoop0
hadoop1
hadoop2
```

##### 3.同步配置文件

```
my_rsync.sh /opt/module/hadoop-3.1.3
```

##### 4.启动集群

```
hdfs namenode -format
sbin/start-dfs.sh
sbin/start-yarn.sh
```

##### 5.浏览器访问hadoop相关信息

```
Web端查看HDFS的NameNode
（a）浏览器中输入：http://hadoop0:9870
（b）查看HDFS上存储的数据信息
Web端查看YARN的ResourceManager
（a）浏览器中输入：http://hadoop1:8088
（b）查看YARN上运行的Job信息
Web端查看jobhistory
 (a) 浏览器中输入：http://hadoop0:19888/jobhistory
```

##### 6.hadoop命令总结

```
1）各个服务组件逐一启动/停止
	（1）分别启动/停止HDFS组件
		hdfs --daemon start/stop namenode/datanode/secondarynamenode
	（2）启动/停止YARN
		yarn --daemon start/stop  resourcemanager/nodemanager
	 (3)启动历史服务器
		mapred --daemon start/stop historyserver
2）各个模块分开启动/停止（配置ssh是前提）常用
	（1）整体启动/停止HDFS
		start-dfs.sh/stop-dfs.sh
	（2）整体启动/停止YARN
		start-yarn.sh/stop-yarn.sh

```

##### 7.补充脚本

* 查看三台服务器java进程脚本：jpsall

```
#!/bin/bash
#
for host in hadoop102 hadoop103 hadoop104
do
        echo =============== $host ===============
        ssh $host jps $@ | grep -v Jps
done

```

* hadoop集群启停脚本（包含hdfs，yarn，historyserver）：myhadoop.sh

```
#!/bin/bash
if [ $# -lt 1 ]
then
    echo "No Args Input..."
    exit ;
fi
case $1 in
"start")
        echo " =================== 启动 hadoop集群 ==================="

        echo " --------------- 启动 hdfs ---------------"
        ssh hadoop102 "/opt/module/hadoop-3.1.3/sbin/start-dfs.sh"
        echo " --------------- 启动 yarn ---------------"
        ssh hadoop103 "/opt/module/hadoop-3.1.3/sbin/start-yarn.sh"
        echo " --------------- 启动 historyserver ---------------"
        ssh hadoop102 "/opt/module/hadoop-3.1.3/bin/mapred --daemon start historyserver"
;;
"stop")
        echo " =================== 关闭 hadoop集群 ==================="

        echo " --------------- 关闭 historyserver ---------------"
        ssh hadoop102 "/opt/module/hadoop-3.1.3/bin/mapred --daemon stop historyserver"
        echo " --------------- 关闭 yarn ---------------"
        ssh hadoop103 "/opt/module/hadoop-3.1.3/sbin/stop-yarn.sh"
        echo " --------------- 关闭 hdfs ---------------"
        ssh hadoop102 "/opt/module/hadoop-3.1.3/sbin/stop-dfs.sh"
;;
*)
    echo "Input Args Error..."
;;
esac

```

* 同步脚本

```
#!/bin/bash
if [ $# -lt 1 ]
then
  echo Not Enough Arguement!
  exit;
fi
for host in hadoop0 hadoop1 hadoop2
do
  echo ====================  $host  ====================
  
  for file in $@
  do
    #4. 判断文件是否存在
    if [ -e $file ]
    then
      #5. 获取父目录
      path=$(cd -P $(dirname $file); pwd)
      #6. 获取当前文件的名称
      fname=$(basename $file)
      ssh $host "mkdir -p $path"
      rsync -av $path/$fname $host:$path
    else
      echo $file does not exists!
    fi
  done
done

```



