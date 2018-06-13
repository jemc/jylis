---
title: Clustering
permalink: /docs/start/clustering/
---

# Clustering

Jylis nodes can be clustered together to increase system availability. Data will automatically replicate between all nodes in the cluster that can connect to each other. Since Jylis is eventually consistent and favors availability, a node that is separated from the cluster will retain the data it was able to replicate before the partition and will continue to respond to reads with the last known value. Likewise, a separated node will also continue to accept writes. Due to the nature of CRDTs, these changes will automatically be reconciled when the node rejoins the cluster. The application may need to decide which value "wins" when fetching this reconciled data, but unlike some other databases no manual repair step is required before the data is available.

## Command Line Options

The following command line options pertain to clustering:

* `--addr` (`-a`) - The `host:port:name` to be advertised to other clustering nodes.
* `--seed-addrs` (`-s`) - A space-separated list of the `host:port:name` for other known nodes.
* `--heartbeat-time` (`-H`) - The number of seconds between heartbeats in the clustering protocol.

## Example Config

The following is an example `docker-compose.yml` file showing three Jylis nodes clustered together. Each node is exposed to the host on ports `6379`, `6380`, and `6381`, respectively.

```yaml
version: "3"
services:
  db1:
    image: jemc/jylis
    ports:
      - "6379:6379"
    command:
      - "--addr=db1:9999:db1"
      - "--seed-addrs=db2:9999:db2 db3:9999:db3"

  db2:
    image: jemc/jylis
    ports:
      - "6380:6379"
    command:
      - "--addr=db2:9999:db2"
      - "--seed-addrs=db1:9999:db1 db3:9999:db3"
    links:
      - db1

  db3:
    image: jemc/jylis
    ports:
      - "6381:6379"
    command:
      - "--addr=db3:9999:db3"
      - "--seed-addrs=db1:9999:db1 db2:9999:db2"
    links:
      - db1
      - db2
```

### Replication In Action

* Prerequisites:
    * Ensure a Redis client is installed. `redis-cli` will be used in this example, but any Redis-compatible client will work.
    * Ensure [docker](https://www.docker.com/community-edition#/download) is installed.
    * Ensure [docker-compose](https://docs.docker.com/compose/install/) is installed.

* Save the `docker-compose.yml` file above to a directory.

* Bring up the cluster with `docker-compose up -d`.

* Connect to `db1` with the command `redis-cli -p 6379`. The client will display the port number on the CLI prompt, which shows you are in fact connected to `db1`: `127.0.0.1:6379>`

* Enter the query: `MVREG SET test 14`. The server will respond `OK`.

* Exit the database CLI with `Ctrl + D`.

* Connect to `db2` with the command `redis-cli -p 6380`.

* Enter the query: `MVREG GET test`. The server will respond `1) "14"`.
