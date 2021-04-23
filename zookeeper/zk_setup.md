### zookeeper分布式搭建

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