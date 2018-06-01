---
title: Disk Persistence
permalink: /docs/start/disk-persistence/
---

# Data Persistence

Although Jylis is an in-memory database, disk persistence is available as an opt-in feature. Enabling persistence writes data to disk, which is read back into memory when the server restarts. To enable disk persistence, start Jylis with the `--disk-dir=<path>` CLI option.

```text
jylis --disk-dir=<path>
```

Even without disk persistence, a Jylis cluster can still retain data beyond a node failure. As long as other nodes in the cluster have a combined view of the data in their collective memory, they will refill the failed node with data when it restarts. Adding disk persistence to one or more nodes adds another dimension of durability, at the cost of increased overhead for operations on those nodes.
