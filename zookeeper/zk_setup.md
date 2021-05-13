### zookeeper分布式搭建

#### 预安装环境

```
zookeeper3.5.7
```

#### 1.安装步骤

```
# 3台机器分别执行
tar -zxvf zookeeper-3.5.7.tar.gz -C /opt/module/
ln -s apache-zookeeper-3.5.7 zookeeper
mkdir -p /opt/module/zookeeper/zkData
touch /opt/module/zookeeper/zkData/myid  //在文件中添加与server对应的编号：
```

#### 2.配置文件

```
mv zoo_sample.cfg zoo.cfg
//修改配置文件
dataDir=/opt/module/zookeeper/zkData
server.0=hadoop0:2888:3888
server.1=hadoop1:2888:3888
server.2=hadoop2:2888:3888
```

#### 3.配置文件解读

```
server.A=B:C:D
A是一个数字，表示这个是第几号服务器；
集群模式下配置一个文件myid，这个文件在dataDir目录下，这个文件里面有一个数据就是A的值，Zookeeper启动时读取此文件，拿到里面的数据与zoo.cfg里面的配置信息比较从而判断到底是哪个server。
B是这个服务器的地址；
C是这个服务器Follower与集群中的Leader服务器交换信息的端口；
D是万一集群中的Leader服务器挂了，需要一个端口来重新进行选举，选出一个新的Leader，而这个端口就是用来执行选举时服务器相互通信的端口。
```

* <span style='color:red'>配置文件详解</span>

```
#tickTime：
这个时间是作为 Zookeeper 服务器之间或客户端与服务器之间维持心跳的时间间隔，也就是每个 tickTime 时间就会发送一个心跳。
#initLimit：
这个配置项是用来配置 Zookeeper 接受客户端（这里所说的客户端不是用户连接 Zookeeper 服务器的客户端，而是 Zookeeper 服务器集群中连接到 Leader 的 Follower 服务器）初始化连接时最长能忍受多少个心跳时间间隔数。当已经超过 5个心跳的时间（也就是 tickTime）长度后 Zookeeper 服务器还没有收到客户端的返回信息，那么表明这个客户端连接失败。总的时间长度就是 5*2000=10 秒
#syncLimit：
这个配置项标识 Leader 与Follower 之间发送消息，请求和应答时间长度，最长不能超过多少个 tickTime 的时间长度，总的时间长度就是5*2000=10秒
#dataDir：
快照日志的存储路径；下面有个myid 文件需要指定 server.x的具体数字
#dataLogDir：
事物日志的存储路径，如果不配置这个那么事物日志会默认存储到dataDir制定的目录，这样会严重影响zk的性能，当zk吞吐量较大的时候，产生的事物日志、快照日志太多
#clientPort：
这个端口就是客户端连接 Zookeeper 服务器的端口，Zookeeper 会监听这个端口，接受客户端的访问请求。修改他的端口改大点
#server.1=192.168.10.10:2888:3888
server.1 这个1是服务器的标识也可以是其他的数字， 表示这个是第几号服务器，用来标识服务器，这个标识要写到快照目录下面myid文件里
192.168.10.10为集群里的IP地址，第一个端口是master和slave之间的通信端口，默认是2888，第二个端口是leader选举的端口，集群刚启动的时候选举或者leader挂掉之后进行新的选举的端口默认是3888
```



#### 4.统一启动脚本

```
#!/bin/bash

if [ $# -lt 1 ]
then
	echo "参数不全"
	exit
fi
for host in hadoop0 hadoop1 hadoop2
do
	for command in "$*"
	do
		echo "#########执行$host#########$command"
		ssh $host $command
	done
done
```

#### 5.客户端命令行操作

| 命令基本语法 | 功能描述                                                     |
| ------------ | ------------------------------------------------------------ |
| help         | 显示所有操作命令                                             |
| ls path      | 使用 ls 命令来查看当前znode的子节点   -w  监听子节点变化   -s   附加次级信息   ，znode 也可以set值 |
| create       | 普通创建   -s  含有序列   -e  临时（重启或者超时消失）       |
| get path     | 获得节点的值   -w  监听节点内容变化   -s   附加次级信息      |
| set          | 设置节点的具体值                                             |
| stat         | 查看节点状态                                                 |
| delete       | 删除节点                                                     |
| deleteall    | 递归删除节点                                                 |