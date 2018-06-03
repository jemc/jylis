---
title: MVREG - Multi-Value Register
permalink: /docs/types/mvreg/
---

# `MVREG` - Multi-Value Register<br>(Observed-Remove Set)

A multi-value register holds a latest value in causal history. This will often be just one value, but may be multiple values if the register was updated concurrently.

Every `SET` operation provides a new value to be assigned to the register. Any locally observable values in the register are removed, so that the only local value is the new desired value. However, if a different value was concurrently written to another replica, there is no clear causal relation between the two new values, and both will be retained. In other words, a multi-value register will usually only have one value, but in the case of conflict a `GET` operation will return multiple values and it will be the job of the application to handle them appropriately.

## Related Data Types

- [`TREG`](../treg) is a register that is guaranteed to always hold a single value, but logical timestamps must be provided to resolve conflicts instead of using causal history, and the conflict resolution is only as valid as those timestamps are.

- [`UJSON`](../ujson) provides broadly expanded functionality with similar semantics to a collection of deeply nested multi-value registers, but requires a JSON parser to use and adds additional complexity to the solution.

## Functions

### `GET key`

Get the latest value(s) for the register at `key`.

Returns an array of strings, where each string is a latest value that was assigned to the register. The order of the array is arbitrary, and applications should not rely upon it for correctness.

If the register has no value, an empty array will be returned.

### `SET key value`

Set the latest `value` for the register at `key`.

Any other value(s) that are locally visible (in the replica where this operation is performed) will be removed, leaving the new desired value as the only locally visible value in that replica.

Values that are not yet locally visible (because they have yet to propagate from other replicas) will be retained upon eventual propagation, leaving the possibility that multiple values will eventually be present, even though each `SET` operation left only one local value.

Returns a simple string reply of `OK`.

## Examples

```sh
jylis> MVREG GET mykey
(empty list)
jylis> MVREG SET mykey "apple"
OK
jylis> MVREG GET mykey
1) "apple"
jylis> MVREG SET mykey "banana"
OK
jylis> MVREG GET mykey
1) "banana"
```

## Detailed Semantics

- Each change operation is recorded as having happend at a relative point in causal history.

- A change `A` *precedes* another change `B` if the effects of change `A` were already locally visible on the same replica when change `B` occurred; the two changes are said to have a *causal relationship*.

- If change `A` and change `B` each happened on a replica where the effects of the other change were not yet locally visible, the two changes have happened concurrently; there is no causal relationship between them.

- `SET` is a change operation that updates the value of the register and shadows only those values whose change operation preceded it in causal history.

## Caveats & Pitfalls

- As with all eventually-consistent data types, you can't guarantee that the value read from any two nodes will be the same. Changes take time to propagate through the distributed system, and your application should be written with the expectation of seeing inconsistent values. In general, you should assume that nothing is immediate, nothing is atomic, and nothing is ordered.

- Even though this data type will return an array with exactly one value in the most common case, your application must have a way of handling the case where more than one value is present due to concurrent updates, and the case where no values are present due to the register having not yet received any updates.
