#### process & server

##### ***process briefly described***

```
Coordinator processes manage data availability on the cluster.
Overlord processes control the assignment of data ingestion workloads.
Broker processes handle queries from external clients.
Router processes are optional processes that can route requests to Brokers, Coordinators, and Overlords.
Historical processes store queryable data.
MiddleManager processes are responsible for ingesting data.
```

***suggest deploy styles***

```
Master: Runs Coordinator and Overlord processes, manages data availability and ingestion.
Query: Runs Broker and optional Router processes, handles queries from external clients.
Data: Runs Historical and MiddleManager processes, executes ingestion workloads and stores all queryable data.
```

