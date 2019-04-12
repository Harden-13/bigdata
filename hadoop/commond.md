##### commond

1. 一个leader，两个follower

```
hadoop-daemons.sh start journalnode 或
/etc/init.d/hadoop-hdfs-journalnode start （三台服务器上都启动）
```

2. 格式化HDFS,格式化zk,启动namenode,启动yarn nn1

```
hadoop namenode -format （在其中一台namenode上操作）
hdfs zkfc -formatZK		（在其中一台namenode上操作,初始化zk中HA的状态）
hdfs namenode -initializeSharedEdits	（在其中一台namenode上操作,初始化共享Edits文件）
hadoop-daemon.sh start namenode 或 /etc/init.d/hadoop-hdfs-namenode start
/etc/init.d/hadoop-hdfs-zkfc start
/etc/init.d/hadoop-yarn-proxyserver start
/etc/init.d/hadoop-mapreduce-historyserver start
/etc/init.d/hadoop-httpfs start

start-dfs.sh
start-yarn.sh
```

3. 完成主备节点同步信息 ,启动yarn的resource manager nn2

```
hdfs namenode -bootstrapStandby  启动nn2上的rm,与nn1上的rm通信
hadoop-daemon.sh start namenode 或 /etc/init.d/hadoop-hdfs-namenode start
/etc/init.d/hadoop-hdfs-zkfc start
start-yarn.sh
```

4. 启动datanode

```
/etc/init.d/hadoop-hdfs-journalnode start
hadoop-yarn-nodemanager restart
```



1. 状态查看

```
hdfs haadmin -getServiceState 
yarn rmadmin -getServiceState 
```

