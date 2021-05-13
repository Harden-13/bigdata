## kafka流程

### 1、写入流程

```
producer 的写入流程
producer 先从 zookeeper 的 "/brokers/.../state" 节点找到该 partition 的 leader 
producer 将消息发送给该 leader 
leader 将消息写入本地 log 
followers 从 leader pull 消息，写入本地 log 后 leader 发送 ACK 
leader 收到所有 ISR 中的 replica 的 ACK 后，增加 HW（high watermark，最后 commit 的 offset） 并向 producer 发送 ACK
 
```

