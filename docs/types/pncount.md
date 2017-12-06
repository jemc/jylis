# `PNCOUNT` - Positive/Negative Counter

A positive/negative counter holds an integer value which can be increased or decreased.

Every `INC` operation increases the "positive" value associated with the node that processed the operation, and the value associated with each node is tracked separately. Similarly, every `DEC` operation increases the negative value. A `GET` operation will return the sum of all such values to determine the net value for that counter across all nodes. As nodes share information and their view of the others' values is updated, they will eventually converge to the same total value.

The value of the counter is a 64-bit signed integer.

## Functions

### `GET key`

Get the resulting `value` for the counter at `key`.

Returns a 64-bit signed integer, which will be `0` if this counter has never been increased or decreased.

### `INC key value`

Increase the counter at `key` by the amount of `value`.

Returns a simple string reply of `OK`.

### `DEC key value`

Decrease the counter at `key` by the amount of `value`.

Returns a simple string reply of `OK`.

## Examples

```sh
jylis> GCOUNT GET mykey
(integer) 0
jylis> GCOUNT INC mykey 10
OK
jylis> GCOUNT GET mykey
(integer) 10
jylis> GCOUNT DEC mykey 15
OK
jylis> GCOUNT GET mykey
(integer) -5
```

## Detailed Semantics

- Two map of values are held in the counter, one representing positive growth, and one representing negative growth, where each value in each map is associated with a particular node identity.

- To converge the data structure, both the positive and negative maps are converged separately.

- Two positive maps or two negative maps `A` and `B` are merged by selecting the value with the greater magnitude for every unique node identity present in either or both maps.

## Caveats & Pitfalls

- As with all eventually-consistent data types, you can't guarantee that the value read from any two nodes will be the same. Changes take time to propagate through the distributed system, and your application should be written with the expectation of seeing inconsistent values. In general, you should assume that nothing is immediate, nothing is atomic, and nothing is ordered.

- Because the value is a signed 64-bit integer, the maximum and minimum value that can be represented is limited. If any one node is increased more than that maximum value, or decreased more than that minimum value, the behavior of the data type will become unpredictable as changes propagate from node to node.

    - When designing a solution, an average "worst case" rate of increase and decrease for the counter should be calculated in order to ensure that it isn't possible for the local positive or negative value of the counter to overflow during the life of the application. Remember that increase and decrease are tracked independently, so a counter with equal amounts of increase and decrease may still be at risk to overflow either or both of the opposing positive and negative values.
