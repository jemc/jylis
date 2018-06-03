---
title: Data Types
permalink: /docs/types/
---

# Data Types

Jylis is a database for CRDTs (Conflict-free Replicated Data Types). Each data type in Jylis defines certain constraints about how it can be used as well as a strategy for merging data from distributed replicas such that each replica is guaranteed to converge to the same result after sufficient information propagation between replicas. This is known as *eventual consistency*.

The primary advantage of CRDTs is that updating data in any replica never requires synchronizing the update with other replicas. In other words, consensus between nodes in the cluster is never required. As a result, we need not pay any penalty to availability or request latency even when working with a distributed cluster over a faulty, high latency network. Information will propagate between replicas asynchronously in the background, and they will eventually reach the same result after overcoming the faults and latency between cluster nodes.

The primary disadvantage of CRDTs is the aforementioned constraints that they impose on the operations that can be performed on them. The merge strategy for each data type must be both commutative and idempotent, and only change operations that are compatible with this strategy may be allowed. Each data type is designed to have constraints that make it as useful as possible for a particular kind of application, but some operations that would potentially be very useful cannot be allowed.

Choosing a data type for your application is a matter of carefully reviewing the semantics, including the operations that are available and their respective constraints and caveats, and selecting a data type whose semantics match your application needs.

If you find that none of the available data types provide the semantics you want, it may be that it is not possible to provide the desired behaviour with a CRDT. Alternatively, it may be that such a data type merely has not been crafted yet. If you think you have an idea for a valid and useful CRDT that is not represented in Jylis yet, please feel free to <a href="https://github.com/jemc/jylis/issues/new">file an issue ticket</a> for discussing the idea.
