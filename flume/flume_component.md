##### flume component

```
source: 完成对日志的收集，分成transtion和event打入到channel中
channel： 主要提供一个队列的功能，对source提供的数据进行简单的缓存
sink: 取出channel中的数据，进行相应的存储文件系统，数据库，或者提交到远程服务器
```

##### 1.source

```
ExecSource: 以运行linux的方式，持续输出最新的数据，tail -F文件名指令，在这种情况下，取得文件名要指定
SpoolSource：检测配置的目录下新增得文件，并将文件中得数据读取出来
			 不可以包含子目录，文件不可打开编辑
```

##### 2.Channel

```
MemoryChannel: 可以实现高速的吞吐，但是无法保证数据的完整性
FileChannel保证数据的完整性与一致性。在具体配置不现的FileChannel时，建议FileChannel设置的目录和程序日志文件保存的目录设成不同的磁盘，以便提高效率
```

##### 3.Sink

```
可以向文件系统中，数据库中，hadoop中储数据，可以像kafka传输数据。
在日志数据较少时，可以将数据存储在文件系中，并且设定一定的时间间隔保存数据。在日志数据较多时，可以将相应的日志数据存储到Hadoop中，便于日后进行相应的数据分析。
```

