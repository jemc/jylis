---
title: Data Persistence
permalink: /docs/start/data-persistence/
---

# Data Persistence

Although Jylis is an in-memory database, persistence is available as an opt-in feature. Enabling persistence writes data to disk, which is read back into memory when the server restarts. To enable persistence, start Jylis with the `--disk-dir=<path>` CLI option.

```text
jylis --disk-dir=<path>
```
