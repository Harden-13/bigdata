##### commond

一个leader，两个follower

```
hadoop-daemons.sh start journalnode
```

格式化HDFS,格式化zk,启动namenode,启动yarn nn1

```
hadoop namenode -format
hadoop-daemon.sh start namenode
hdfs zkfc -formatZK
start-dfs.sh
start-yarn.sh
```

完成主备节点同步信息 ,启动yarn的resource manager nn2

```
hdfs namenode -bootstrapStandby  启动nn2上的rm,与nn1上的rm通信
start-yarn.sh
```

状态查看

```
hdfs haadmin -getServiceState 
yarn rmadmin -getServiceState 
```

