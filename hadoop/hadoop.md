#### hadoop ha configuration about hdfs.site.xml

​	This guide discusses how to configure and use HDFS HA using the Quorum Journal Manager (QJM) to 			share edit logs between the Active and Standby NameNodes. For information on how to configure HDFS HA using NFS for shared storage instead of the QJM	

1. 1. **dfs.nameservices** - the logical name for this new nameservice

   ```
   <property>
     <name>dfs.nameservices</name>
     <value>mycluster</value>
   </property>
   ```

   2. **dfs.ha.namenodes.[nameservice ID]** - unique identifiers for each NameNode in the nameservice & only a maximum of two NameNodes may be configured per nameservice	

   ```
   <property>
     <name>dfs.ha.namenodes.mycluster</name>
     <value>nn1,nn2</value>
   </property>
   ```

   3. **dfs.namenode.rpc-address.[nameservice ID].[name node ID]** - the fully-qualified RPC address for each NameNode to listen on  & For both of the previously-configured NameNode IDs, set the full address and IPC port of the NameNode processs

   ```
     <property>
       <name>dfs.namenode.rpc-address.emr-cluster.nn1</name>
       <value>emr-header-1.cluster-42589:8020</value>
     </property>
     <property>
       <!-提供HDFS的RESTful接口，可通过此接口进行HDFS文件操作,默认开启->
       <!-如果访问大文件时，HttpFS服务本身有可能变成瓶颈。当然，如果你想限制客户端流量，以防其过度占用集群的带宽时，那就要考虑HttpFS了->
       <!-curl "http://ctrl:50070/webhdfs/v1/?op=liststatus&user.name=root" | python -mjson.tool->
       <name>dfs.webhdfs.enabled</name>
       <value>false</value>
     </property>
     <property>
       <name>dfs.namenode.rpc-address.emr-cluster.nn2</name>
       <value>emr-header-2.cluster-42589:8020</value>
     </property>
   ```

   4. **dfs.namenode.http-address.[nameservice ID].[name node ID]** - the fully-qualified HTTP address for each NameNode to listen on

   ```
   <property>
     <name>dfs.namenode.http-address.emr-cluster.nn1</name>
     <value>emr-header-1.cluster-42589:50070</value>
   </property>
   <property>
     <name>dfs.namenode.http-address.emr-cluster.nn2</name>
     <value>emr-header-2.cluster-42589:50070</value>
   </property>
   ```

   5. **dfs.namenode.shared.edits.dir** - the URI which identifies the group of JNs where the NameNodes will write/read edits

      两个NameNode为了数据同步，会通过一组称作JournalNodes的独立进程进行相互通信。当active状态的NameNode的命名空间有任何修改时，会告知大部分的JournalNodes进程。standby状态的NameNode有能力读取JNs中的变更信息，并且一直监控edit log的变化，把变化应用于自己的命名空间。standby可以确保在集群出错时，命名空间状态已经完全同步了。

   ```
   <property>
     <name>dfs.namenode.shared.edits.dir</name>
     <value>qjournal://emr-worker-1.cluster-42589:8485;emr-header-2.cluster-42589:8485;emr-header-1.cluster-42589:8485/emr-cluster</value>
   </property>
   ```

   6. **dfs.client.failover.proxy.provider.[nameservice ID]** - the Java class that HDFS clients use to contact the Active NameNode

   ```
   <property>
     <name>dfs.client.failover.proxy.provider.mycluster</name>    				<value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
   </property>
   ```

   7. **dfs.ha.fencing.methods** - a list of scripts or Java classes which will be used to fence the Active NameNode during a failover

   ```
   <property>
     <name>dfs.ha.fencing.methods</name>
     <value>shell(/bin/true)</value>
   </property>
   ```

   8. **fs.defaultFS** - default path prefix used by the Hadoop FS client when none is given,in my **core-site.xml** file:

   ```
   <property>
     <name>fs.defaultFS</name>
     <value>hdfs://mycluster</value>
   </property>
   ```

   9. **dfs.journalnode.edits.dir** - the path where the JournalNode daemon will store its local state

   ```
   <property>
     <name>dfs.journalnode.edits.dir</name>
     <value>/mnt/disk1/hdfs/journal</value>
   </property>
   ```

##### 备注

```
dfs.namenode.checkpoint.dir：file:///mnt/disk1/hdfs/namesecondary
Determines where on the local filesystem the DFS secondary name node should store the temporary images to merge. If this is a comma-delimited list of directories then the image is replicated in all of the directories for redundancy.
```

