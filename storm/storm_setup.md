#### reference

https://www-eu.apache.org/dist/storm/apache-storm-1.2.2/apache-storm-1.2.2.tar.gz

http://storm.apache.org/releases/1.2.2/Setting-up-a-Storm-cluster.html

#### storm setup cluster

1. set up a zookeeper cluster

2. install dependencies on nimbus and worker machines

   ```
   1. Java 7+ (Apache Storm 1.x is tested through travis ci against both java 7 and java 8 JDKs)
   2. Python 2.6.6 (Python 3.x should work too, but is not tested as part of our CI enviornment)
   ```

3. configuration into storm.yaml

   ```
   storm.zookeeper.servers:
       - "10.10.103.45"
       - "10.10.103.46"
       - "10.10.103.47"
   storm.local.dir: "/data/storm"
   nimbus.seeds: ["10.10.103.45"]
   supervisor.slots.prots:
       - 6700
       - 6701
       - 6702
   storm.health.check.dir: "healthchecks"
   storm.health.check.timeout.ms: 5000
   ```

4. launch daemons

   ```
   Nimbus: Run the command "bin/storm nimbus" under supervision on the master machine.
   Supervisor: Run the command "bin/storm supervisor" under supervision on each worker machine. The supervisor daemon is responsible for starting and stopping worker processes on that machine.
   UI: Run the Storm UI (a site you can access from the browser that gives diagnostics on the cluster and topologies) by running the command "bin/storm ui" under supervision. The UI can be accessed by navigating your web browser to http://{ui host}:8080.
   ```

5. 

