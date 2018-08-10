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
