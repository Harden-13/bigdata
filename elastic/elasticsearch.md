##### elasticsearch

```
index(索引)：相当于databases数据库；索引是被分片分开存储的，一个索引默认分成5个分片；默认每个分片生成一个副本
types(类型)：相当于table表
documents(行)：相当于row行
fields(列)：相当于colums列
```

##### es node type

```
Master(主节点)：创建删除索引，跟踪哪些节点是集群的一部分，并决定哪些分片分配给相关节点，默认情况下任何一个集群中的节点都有可能被选为主节点。索引数据和搜索查询等操作会占用大量的cpu，内存，io资源，为了确保一个集群的稳定，分离主节点和数据节点是一个比较好的选择。
Data(数据节点)：数据节点主要是存储索引数据的节点，主要对文档进行增删改查操作，聚合操作等。数据节点对 CPU、内存、IO 要求较高，在优化的时候需要监控数据节点的状态，当资源不够的时候，需要在集群中添加新的节点
Client(负载均衡节点)：独立的客户端节点在一个比较大的集群中是非常有用的，他协调主节点和数据节点，客户端节点加入集群可以得到集群的状态，根据集群的状态可以直接路由请求。
Ingest(预处理节点)：在索引数据之前可以先对数据做预处理操作
备注：具体的类型可以通过具体的配置文件来设置，但如果一个节点既不是主节点也不是数据节点，那么它就是负载均衡节点
```

##### install elasticsearch with rpm

```
#java use 1.8.0_131 or a later version
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
vim /etc/yum.repos.d/elasticsearch.repo
	[elasticsearch-6.x]
    name=Elasticsearch repository for 6.x packages
    baseurl=https://artifacts.elastic.co/packages/6.x/yum
    gpgcheck=1
    gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
    enabled=1
    autorefresh=1
    type=rpm-md
yum install elasticsearch
```

##### edit configure file

```
vim /etc/elasticsearch/elasticsearch.yml
cluster.name: online-elasticsearch #集群是一个整体，因此集群中所有主机名称都要一致
node.name: node-x           #每个节点都是集群的一部分，每个节点名称都不要相同，可以按照顺序编号
node.master: true	#注意这里是有资格成为主节点，不是一定会成为主节点，主节点需要集群经过选举产生
node.data: true #node.data 可以配置该节点是否为数据节点，如果配置为 true，则主机就会作为数据节					点，注意主节点也可以作为数据节点，当 node.master 和 node.data 均为 false，则						该主机会作为负载均衡节点。这里我配置所有主机都是数据节点，因此都配置为 true
path.data: /data/elasticsearch/data
path.logs: /data/elasticsearch/logs  #可以配置 Elasticsearch 的数据存储路径和日志存储路径
network.host: 0.0.0.0#默认是无法公开访问的，如果设置为主机的公网 IP 或 0.0.0.0 就是可以公开访问的
http.port: 9200
discovery.zen.ping.unicast.hosts: ["python0", "python1","python2"] #集群的主机地址，配置之后集群的主机之间可以自动发现
discovery.zen.minimum_master_nodes: 2 #为了防止集群发生“脑裂”，即一个集群分裂成多个，通常需要配置集群最少主节点数目，通常为 (可成为主节点的主机数目 / 2) + 1
gateway.recover_after_nodes: 2 #配置当最少几个节点回复之后，集群就正常工作
```

##### start elasticsearch

```
sudo systemctl enable elasticsearch.service
sudo systemctl start elasticsearch.service
```

##### cluster status

```
curl -XGET 'http://localhost:9200/_cluster/state?pretty'
```

