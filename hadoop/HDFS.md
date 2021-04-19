#### **HDFS**

#### 1.hdfs组成架构

* NameNode(nn),就是master，它是一个管理者

```
1.管理hdfs的名称空间
2.配置副本策略
3.管理数据块（Block）的映射信息
4.处理客户端读写请求
```

* DataNiode(dn),就是slave,dn执行来自nn命令的实际操作

```
1.存储实际的数据块
2.执行数据块的读写操作
```

* client客户端（接口）

```
1.文件上传时，client将文件切分成一个个block，在上传
2.与nn交互，获取文件的位置信息
3.与dn交互读取或写入数据
4.client提供一些命令来管理hdfs，比如nn格式化
5.client可以通过命令访问hdfs，比如对hdfs增删改查
```

* secondary NameNode,无法解决单点故障，不能在nn挂掉后马上替换nn提供服务

```
1.辅助nn，分担其工作量，比如定期合并fsimage和edit，并推送给namenode
2，紧急情况下和辅助恢复nn
```

##### 2.hdfs优缺点

* 缺点

```
1.不适合做低延时的数据访问，区别于mysql
2.无法高效的对大量小文件进行存储
	1）存储大量小文件的话，它会占用nn的大量内存来存储文件目录和块信息,nn内存是有限的
	2）小文件存储的寻址时间会超过读取时间，违反了hdfs设计
3.不支持并发写入，文件随机修改；
	1）一个文件只能由一个写不允许多个线城同时写
	2）仅支持数据的追加，不可以修改
```

##### 3.hdfs文件块大小

```
1.hdfs在物理上是分块存储块的大小可以通过（dfs,blocksize）来规定，默认128M
2.如果寻址时间10ms，查找到目标block的时间就为10ms
3.寻址时间为传输时间1%为最佳状态 因此10/0.01，传输时间1s
4.目前普遍磁盘传输速度100mb/s，所以计算机取128M
总结:
hdfs块的大小设置主要取决于磁盘传输速率
hdfs块设置的小会增加寻址时间
hdfs块设置的大会增加传输时间
```

##### 5.hdfs上传下载命令使用

* -moveFromLocal：从本地剪切粘贴到HDFS

```\
hadoop fs  -moveFromLocal  ./filename  /hadoop
```

* -copyFromLocal：从本地文件系统中拷贝文件到HDFS路径去

```
hadoop fs -copyFromLocal ./harden.txt /hadoop
```

* -appendToFile：追加一个文件到已经存在的文件末尾

```
hadoop fs -appendToFile ./filenameA /hadoop/filenameB
```

* -put：等同于copyFromLocal

```
hadoop fs -put ./filename /test
```

* -copyToLocal：从HDFS拷贝到本地

```
hadoop fs -copyToLocal /hadoop/filename ./
```

* -get：等同于copyToLocal，就是从HDFS下载文件到本地

```
hadoop fs -get /hadoop/filename ./
```

* -getmerge：合并下载多个文件，比如HDFS的目录 /user/atguigu/test下有多个文件:log.1,
  log.2,log.3,...

```
hadoop fs -getmerge /hadoop/* ./zaiyiqi.txt
```

##### 6.hdfs直接操作

```
1)-ls: 显示目录信息
hadoop fs -ls /
2）-mkdir：在HDFS上创建目录
hadoop fs -mkdir -p /aa/bb
3）-cat：显示文件内容
hadoop fs -cat /aa/bb/kongming.txt
4）-chgrp 、-chmod、-chown：Linux文件系统中的用法一样，修改文件所属权限
hadoop fs  -chmod  666  /aa/bb/kongming.txt
hadoop fs  -chown  hadoop:hadoop /aa/bb/kongming.txt
5）-cp ：从HDFS的一个路径拷贝到HDFS的另一个路径
hadoop fs -cp /aa/bb/kongming.txt /zhuge.txt
6）-mv：在HDFS目录中移动文件
hadoop fs -mv /zhuge.txt /aa/bb/
7）-tail：显示一个文件的末尾1kb的数据
hadoop fs -tail /aa/bb/kongming.txt
8）-rm：删除文件或文件夹
hadoop fs -rm /user/test/jinlian2.txt
9）-rmdir：删除空目录
hadoop fs -mkdir /test
hadoop fs -rmdir /test
10）-du统计文件夹的大小信息
hadoop fs -du -s -h /user/test
2.7 K  /user/test

hadoop fs -du  -h /user/atguigu/test
1.3 K  /user/test/README.txt
15     /user/test/jinlian.txt
1.4 K  /user/test/zaiyiqi.txt
11）-setrep：设置HDFS中文件的副本数量
hadoop fs -setrep 10 /aa/bb/kongming.txt
 
这里设置的副本数只是记录在NameNode的元数据中，是否真的会有这么多副本，还得看DataNode的数量。因为目前只有3台设备，最多也就3个副本，只有节点数的增加到10台时，副本数才能达到10。

```

##### 7.hdfs流程

* hdfs写数据流程

```
（1）客户端通过Distributed FileSystem模块向NameNode请求上传文件，NameNode检查目标文件是否已存在，父目录是否存在。
（2）NameNode返回是否可以上传。
（3）客户端请求第一个 Block上传到哪几个DataNode服务器上。
（4）NameNode返回3个DataNode节点，分别为dn1、dn2、dn3。
（5）客户端通过FSDataOutputStream模块请求dn1上传数据，dn1收到请求会继续调用dn2，然后dn2调用dn3，将这个通信管道建立完成。
（6）dn1、dn2、dn3逐级应答客户端。
（7）客户端开始往dn1上传第一个Block（先从磁盘读取数据放到一个本地内存缓存），以Packet为单位，dn1收到一个Packet就会传给dn2，dn2传给dn3；dn1每传一个packet会放入一个应答队列等待应答。(client与db1,dn2,dn3为串行连接)
（8）当一个Block传输完成之后，客户端再次请求NameNode上传第二个Block的服务器。（重复执行3-7步）。
源码解析：org.apache.hadoop.hdfs.DFSOutputStream 
参见图片hadoopwrite.png
```

* hdfs读数据流程

```
（1）客户端通过DistributedFileSystem向NameNode请求下载文件，NameNode通过查询元数据，找到文件块所在的DataNode地址。
（2）挑选一台DataNode（就近原则，然后随机）服务器，请求读取数据。
（3）DataNode开始传输数据给客户端（从磁盘里面读取数据输入流，以Packet(64K)为单位来做校验）。
（4）客户端以Packet为单位接收，先在本地缓存，然后写入目标文件。
参见图片hdfsread.png
```

##### 8.节点距离计算

* 在HDFS写数据的过程中，nn会选择距离待上传数据最近距离的dn接收数据

```
节点距离：两个节点到达最近的共同祖先的距离总和。
假设有数据中心d1机架r1中的节点n1。该节点可以表示为/d1/r1/n1。利用这种标记
```

##### 9.机架感知

* 机架感知（副本存储节点选择）

```
http://hadoop.apache.org/docs/r3.1.3/hadoop-project-dist/hadoop-hdfs/HdfsDesign.html#Data_Replication
```

```
1.第一个副本在client所处的节点上，如果操作的客户端不在集群内，随机选择一个
2.第二个副本在另外一个机架的随机节点
3.第三个副本在第二个副本所在机架的随机节点
```

##### 10.NameNode和SecondaryNameNode

* sn产生原因

```
nn元数据在内存--->避免掉电易失，持久化FsImage（备份元数据）--->同时操作内存元数据，FsImage效率底--->edits(只追加)--->修改元数据同时追加到edits--->定期操作edits,FsImage--->这个工作由secondaryNamenode节点操作
```

* nn&sn工作原理

```
1）第一阶段：NameNode启动
（1）第一次启动NameNode格式化后，创建Fsimage和Edits文件。如果不是第一次启动，直接加载编辑日志和镜像文件到内存。
（2）客户端对元数据进行增删改的请求。
（3）NameNode记录操作日志，更新滚动日志。
（4）NameNode在内存中对元数据进行增删改。
2）第二阶段：Secondary NameNode工作
（1）Secondary NameNode询问NameNode是否需要CheckPoint。直接带回NameNode是否检查结果。
（2）Secondary NameNode请求执行CheckPoint。
（3）NameNode滚动正在写的Edits日志。
（4）将滚动前的编辑日志和镜像文件拷贝到Secondary NameNode。
（5）Secondary NameNode加载编辑日志和镜像文件到内存，并合并。
（6）生成新的镜像文件fsimage.chkpoint。
（7）拷贝fsimage.chkpoint到NameNode。
（8）NameNode将fsimage.chkpoint重新命名成fsimage。

```

* nn&sn工作机制详解

```
NN和2NN工作机制详解：
Fsimage：NameNode内存中元数据序列化后形成的文件。
Edits：记录客户端更新元数据信息的每一步操作（可通过Edits运算出元数据）。
NameNode启动时，先滚动Edits并生成一个空的edits.inprogress，然后加载Edits和Fsimage到内存中，此时NameNode内存就持有最新的元数据信息。Client开始对NameNode发送元数据的增删改的请求，这些请求的操作首先会被记录到edits.inprogress中（查询元数据的操作不会被记录在Edits中，因为查询操作不会更改元数据信息），如果此时NameNode挂掉，重启后会从Edits中读取元数据的信息。然后，NameNode会在内存中执行元数据的增删改的操作。
由于Edits中记录的操作会越来越多，Edits文件会越来越大，导致NameNode在启动加载Edits时会很慢，所以需要对Edits和Fsimage进行合并（所谓合并，就是将Edits和Fsimage加载到内存中，照着Edits中的操作一步步执行，最终形成新的Fsimage）。SecondaryNameNode的作用就是帮助NameNode进行Edits和Fsimage的合并工作。
SecondaryNameNode首先会询问NameNode是否需要CheckPoint（触发CheckPoint需要满足两个条件中的任意一个，定时时间到和Edits中数据写满了）。直接带回NameNode是否检查结果。SecondaryNameNode执行CheckPoint操作，首先会让NameNode滚动Edits并生成一个空的edits.inprogress，滚动Edits的目的是给Edits打个标记，以后所有新的操作都写入edits.inprogress，其他未合并的Edits和Fsimage会拷贝到SecondaryNameNode的本地，然后将拷贝的Edits和Fsimage加载到内存中进行合并，生成fsimage.chkpoint，然后将fsimage.chkpoint拷贝给NameNode，重命名为Fsimage后替换掉原来的Fsimage。NameNode在启动时就只需要加载之前未合并的Edits和Fsimage即可，因为合并过的Edits中的元数据信息已经被记录在Fsimage中。

```

* 谁负责对NN的元数据信息进行合并？

```
2NN主要负责对NN的元数据精心合并，当满足一定条件的下，2NN会检测本地时间，每隔
		一个小时会主动对NN的edits文件和fsimage文件进行一次合并。合并的时候，首先会通知NN,这时候NN就会停止对正在使用的edits文件的追加，同时会新建一个新的edits编辑日志文件，保证NN的正常工作。接下来 2NN会把NN本地的fsimage文件和edits编辑日志拉取2NN的本地，在内存中对二者进行合并，最后产生最新fsimage文件。把最新的fsimage文件再发送给NN的本地。注意还有一个情况，当NN的edits文件中的操作次数累计达到100万次，即便还没到1小时，2NN（每隔60秒会检测一次NN方的edits文件的操作次数）也会进行合并。2NN 也会自己把最新的fsimage文件备份一份。
```



##### 11 Fsimage&Edit

* nn在被格式化后将在/opt/module/hadoop-3.1.3/data/dfs/name/current产生如下文件

```
-rw-rw-r--. 1  edits_0000000000000000001-0000000000000000001
-rw-rw-r--. 1  edits_0000000000000000002-0000000000000000002
-rw-rw-r--. 1  edits_0000000000000000003-0000000000000000004
-rw-rw-r--. 1  edits_0000000000000000005-0000000000000000005
-rw-rw-r--. 1  edits_0000000000000000006-0000000000000000007
-rw-rw-r--. 1  edits_inprogress_0000000000000000008
-rw-rw-r--. 1 hadoop hadoop     393 Apr 12 20:43 fsimage_0000000000000000004
-rw-rw-r--. 1 hadoop hadoop      62 Apr 12 20:43 fsimage_0000000000000000004.md5
-rw-rw-r--. 1 hadoop hadoop     393 Apr 12 21:09 fsimage_0000000000000000007
-rw-rw-r--. 1 hadoop hadoop      62 Apr 12 21:09 fsimage_0000000000000000007.md5
-rw-rw-r--. 1 hadoop hadoop       2 Apr 12 21:09 seen_txid
-rw-rw-r--. 1 hadoop hadoop     217 Apr 12 20:31 VERSION
[root@hadoop0 current]# 

```

```
fsimage文件:hdfs文件系统元数据的一个永久性的检查点，其中包含hdfs文件系统所有的目录和inode的序列化信息
edits文件：存放hdfs文件系统的所有更新操作的路径，文件系统客户端执行的所有写操作首先会被记录到edits文件中
seen_txid文件保存的是一个数字，就是最后一个edits_的数字
每次nn启动的时候都会将Fsimage文件读入内存，加载edits更新操作，保证元数据是罪行的，可以看成nn启动时候就会合并
```

* oiv查看Fsimage文件

```
oiv            apply the offline fsimage viewer to an fsimage
oev            apply the offline edits viewer to an edits file
```

```
 pwd
/opt/module/hadoop-3.1.3/data/dfs/name/current

hdfs oiv -p XML -i fsimage_0000000000000000025 -o /opt/module/hadoop-3.1.3/fsimage.xml

cat /opt/module/hadoop-3.1.3/fsimage.xml
备注
将显示的xml文件内容拷贝到IDEA中创建的xml文件中，并格式化
```

* oev查看Edits文件
* hdfs oev -p 文件类型 -i编辑日志 -o 转换后文件输出路径

```
hdfs oev -p XML -i edits_0000000000000000012-0000000000000000013 -o 
cat /opt/module/hadoop-3.1.3/edits.xml
```



#### 2.DataNode 

##### 1.dn工作机制

```
（1）一个数据块在DataNode上以文件形式存储在磁盘上，包括两个文件，一个是数据本身，一个是元数据包括数据块的长度，块数据的校验和，以及时间戳。
（2）DataNode启动后向NameNode注册，通过后，周期性（1小时）的向NameNode上报所有的块信息。
（3）心跳是每3秒一次，心跳返回结果带有NameNode给该DataNode的命令如复制块数据到另一台机器，或删除某个数据块。如果超过10分钟没有收到某个DataNode的心跳，则认为该节点不可用。
（4）集群运行中可以安全加入和退出一些机器。

```

##### 2.数据的完整性

```
（1）当DataNode读取Block的时候，它会计算CheckSum。
（2）如果计算后的CheckSum，与Block创建时值不一样，说明Block已经损坏。
（3）Client读取其他DataNode上的Block。
（4）常见的校验算法 crc（32），md5（128），sha1（160）
（5）DataNode在其文件创建后周期验证CheckSum。

```

##### 3.掉线的参数设置

* 1.理论掉线值

```
timeout = 2*dfs.namenodeheartbeat.recheck.interval+10*dfs.hearbeat.interval
备注：
dfs.namenodeheartbeat.recheck.interval=300s
dfs.hearbeat.interval=30s
```

* 2.配置文件更改（hdfs.site.xml）

```
<property>
    <name>dfs.namenode.heartbeat.recheck-interval</name>
    <value>300000</value>
</property>
<property>
    <name>dfs.heartbeat.interval</name>
    <value>3</value>
</property>

```

##### 4.扩容

```
1.从任意dn节点copy hadoop目录
2.worker文件增加hadoop3
3.在nn节点启动集群管理脚本（start_dfs.sh）(start_yarn.sh)
4. ./start-balancer.sh
```

##### 5.缩容

* 黑白名单

```
白名单和黑名单是hadoop管理集群主机的一种机制。
添加到白名单的主机节点，都允许访问NameNode，不在白名单的主机节点，都会被退出。添加到黑名单的主机节点，不允许访问NameNode，会在数据迁移后退出。
实际情况下，白名单用于确定允许访问NameNode的DataNode节点，内容配置一般与workers文件内容一致。 黑名单用于在集群运行过程中退役DataNode节点。

```

* 在nn节点的$HADOOP_HOME/etc/hadoop目录下分别创建whitelist 和blacklist文件

```
touch whitelist
touch blacklist
在whitelist中添加如下主机名称,假如集群正常工作的节点为hadoop0,hadoop1,hadoop2
```

* hdfs-site.xml配置文件中增加dfs.hosts和 dfs.hosts.exclude配置参数

```
<!-- 白名单 -->
<property>
<name>dfs.hosts</name>
<value>/opt/module/hadoop-3.1.3/etc/hadoop/whitelist</value>
</property>
<!-- 黑名单 -->
<property>
<name>dfs.hosts.exclude</name>
<value>/opt/module/hadoop-3.1.3/etc/hadoop/blacklist</value>
</property>

```



