##### reference

https://github.com/yahoo/storm-yarn

https://www.tuicool.com/articles/BFr2Yv

##### set up storm on yarn

1. prerequisite

   ```
   Install Java 8 and Maven 3 first.
   Make sure Hadoop YARN have been properly launched.
   ```

2. download & build (puth distribution.xml fiel in the same path )

   ```
   <properties>
          <storm.version>1.0.1</storm.version>
          <hadoop.version>2.6.0-cdh5.11.0</hadoop.version>
   </properties>
   ```

3. mvn

   ```
   mvn package -DskipTests
   ```

4. storm.1-0-1  & storm-on-yarn in the same path

   ```
   storm on yarn 依赖于 storm服务.部署storm集群,并启动storm集群，把storm-on-yarn生成的lib以来考到storm/lib不包括(storm-yarn*.jar)
   ```

5. env

   ```
   ###storm-yarn
   export STORMYARN_HOME=/usr/local/storm-on-yarn
   export PATH=$PATH:$STORMYARN_HOME/bin
   ###storm
   export STORM_HOME=/usr/local/storm-1.0.1/
   export PATH=$PATH:$STORM_HOME/bin
   ```

6. storm-1.0.1 upload to hdfs

   ```
   hadoop fs -mkdir /lib 
   hadoop fs -mkdir /lib/storm
   hadoop fs -mkdir /lib/storm/1.0.1
   zip -r storm.zip storm-1.0.1
   hadoop fs -put storm.zip /lib/storm/1.0.1/
   ```

7. launch  

   ```
   storm-yarn launch /usr/local/storm-1.0.1/conf/storm.yaml -queue=offline
   备注
   capacity-scheduler.xml queue的信息从这个配置文件设置
   ```

8. command

   ```hadoop fs -cat hdfs://10.10.103.45:8020/var/log/hadoop-yarn/apps/root/logs/application_1555998667759_0005/ip-10-10-103-47.ec2.internal_35749
   yarn application -kill
   hadoop fs -cat hdfs://10.10.103.45:8020/var/log/hadoop-yarn/apps/root/logs/
   ```

9. dd