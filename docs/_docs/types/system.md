---
title: SYSTEM - System Functions
permalink: /docs/types/system/
---

# `SYSTEM` - System Functions

In addition to functions that read and write data to data types, some system-level functions are also provided that may be useful in administering Jylis.

## Functions

### `GETLOG`

Read recent entries from the system log, which is an interleaved sequence of log entries from all nodes in the cluster. The system log is collected and represented in the same way as a [`TLOG`](../tlog).

Local server timestamps (unix time in milliseconds) are used as the logical timestamps that control the total order of the log entries from the cluster, so clock disparity between nodes may impact the final order of entries.

The system log is kept trimmed to a fixed maximum length to avoid unbounded memory growth. The trim length can be set at startup using the `--system-log-trim` CLI option.

Returns an array where each element is a two-element array containing the value and timestamp of that entry.

The values will be returned as string, and the timestamps as integers.

### `FORGETALL`

Clear all data from the local in-memory database for this node. This is intended for use in application testing environments.

If in a cluster, data will remain in the other nodes, meaning that all of the cleared data will be restored locally over time using the normal anti-entropy repair mechanisms - the local node will still be eventually consistent with the rest of the cluster.

This command is not meant to be used in conjunction with disk persistence, but if used when disk persistence is enabled, there are no guarantees about how much of the data will remain present on the local disk in the immediate or short term. However, if in a cluster, eventual consistency guarantees with the other nodes in the cluster will still hold as described in the paragraph above.

Returns a simple string reply of `OK` immediately, while the database is being cleared asynchronously.
