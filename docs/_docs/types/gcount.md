---
title: GCOUNT - Grow-Only Counter
permalink: /docs/types/gcount/
---

# `GCOUNT` - Grow-Only Counter

A grow-only counter holds an integer value that can only be increased.

Every `INC` operation increases the value associated with the node that processed the operation, and the value associated with each node is tracked separately. A `GET` operation will return the sum of all such values to determine the total increase for that counter across all nodes. As nodes share information and their view of the others' values is updated, they will eventually converge to the same total value.

The value of the counter is a 64-bit unsigned integer.

## Related Data Types

- [`PNCOUNT`](../pncount) is a similar data type that allows both increasing and decreasing the value.

## Functions

### `GET key`

Get the resulting `value` for the counter at `key`.

Returns a 64-bit unsigned integer, which will be `0` if this counter has never been increased.

### `INC key value`

Increase the counter at `key` by the amount of `value`.

Returns a simple string reply of `OK`.

## Examples

```sh
jylis> GCOUNT GET mykey
(integer) 0
jylis> GCOUNT INC mykey 10
OK
jylis> GCOUNT GET mykey
(integer) 10
jylis> GCOUNT INC mykey 15
OK
jylis> GCOUNT GET mykey
(integer) 25
```

## Detailed Semantics

- A map of values is held in the counter, where each value in the map is associated with a particular node identity.

- Two maps `A` and `B` are merged by selecting the higher value for every unique node identity present in either or both maps.

## Caveats & Pitfalls

- As with all eventually-consistent data types, you can't guarantee that the value read from any two nodes will be the same. Changes take time to propagate through the distributed system, and your application should be written with the expectation of seeing inconsistent values. In general, you should assume that nothing is immediate, nothing is atomic, and nothing is ordered.

- Because the value is an unsigned 64-bit integer, the maximum value that can be represented is limited. If any one node is increased more than that maximum value, or if the sum of all node-local values is greater than that maximum, the value of the counter will be saturated at that maximum value, and any further increases will not result in an increase of the total value. That is, integer overflows are caught, and any additional increase over the maximum is ignored.

    - When designing a solution, an average "worst case" rate of increase for the counter should be calculated in order to ensure that it isn't possible for the local value of the counter to reach the 64-bit integer maximum during the life of the application.
