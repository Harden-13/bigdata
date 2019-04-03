##### zk architecture

```
通过将分布式应用配置为在更多系统上运行，可以进一步减少完成任务的时间。分布式应用正在运行的一组系统称为  **集群**，而在集群中运行的每台机器被称为**节点**
分布式应用有两部分， **Server(服务器)** 和 **Client(客户端)** 应用程序。服务器应用程序实际上是分布式的，并具有通用接口，以便客户端可以连接到集群中的任何服务器并获得相同的结果。 客户端应用程序是与分布式应用进行交互的工具。
ensemable : ZooKeeper服务器组。形成ensemble所需的最小节点数为3。
leader : 	服务器节点，如果任何连接的节点失败，则执行自动恢复。Leader在服务启动时被选举。
follow :	跟随leader指令的服务器节点。
```

##### zk namespace

```
ZooKeeper节点称为**znode** 。每个znode由一个名称标识，并用路径(/)序列分隔;在根目录下，你有两个逻辑命名空间**config**和**workers**
**config**命名空间用于集中式配置管理，**workers**命名空间用于命名
```

##### zk summarize

```
zk集合中写入过程，要比读取过程贵；因为所有节点都需要在数据库中写入相同的数据。因此，对于平衡的环境拥有较少数量（例如3，5，7）的节点比拥有大量的节点要好
```

##### zk component

```
write ： 	写入过程由leader节点处理。leader将写入请求转发到所有znode，并等待znode的回复。如果一半的znode回复，则写入过程完成。
read ： 		读取由特定连接的znode在内部执行，因此不需要与集群进行交互。
replicated db : 它用于在zookeeper中存储数据。每个znode都有自己的数据库，每个znode在一致性的帮助下每次都有相同的数据。
leader : 	Leader是负责处理写入请求的Znode。
follower :	follower从客户端接收写入请求，并将它们转发到leader znode。
request processor : 只存在于leader节点。它管理来自follower节点的写入请求。
atomic broadcasts : 负责广播从leader节点到follower节点的变化。
```

##### zk cli

```
1、创建znode
2、获取数据
3、监视znode的变化
4、设置数据
5、创建znode的子节点
6、列出znode的子节点
7、检查状态
8、移除/删除znode
```

