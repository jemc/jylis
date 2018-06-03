---
title: TREG - Timestamped Register
permalink: /docs/types/treg/
---

# `TREG` - Timestamped Register<br>(Latest Write Wins)

A timestamped register holds a single value and a logical timestamp associated with it.

Every `SET` operation provides a new logical timestamp alongside the new value to be set in the register. If the new timestamp higher than the old timestamp, the write is respected; otherwise, it is discarded. Thus, every `GET` operation will return the value with the highest timestamp that has been seen by that node, and as nodes share information, they will eventually converge to the same "latest" value and timestamp.

The logical timestamp is a 64-bit unsigned integer. It may be used to represent anything appropriate to the application; perhaps milliseconds since the unix epoch, or perhaps a sequence number.

## Related Data Types

- [`TLOG`](../tlog) is another data type that uses logical timestamps, but it retains a sorted list of entries rather than having each later entry overwrite the earlier ones.

- [`MVREG`](../mvreg) is a register that uses a conflict resolution strategy that requires no timestamps, but is unable to resolve every kind of conflict and leaves multiple values in the register when the causal order in which they were written is indeterminate.

## Functions

### `GET key`

Get the latest `value` and `timestamp` for the register at `key`.

The value/timestamp pair currently held in the register will be returned to the caller. This will always be the pair with the latest timestamp that has been seen by the node answering this query.

Returns a two-element array with the current value and the logical timestamp.

The value will be returned as a string, and the timestamp as an integer. If this register has not yet seen a value/timestamp pair written to it, the timestamp will be zero and the value will be an empty string.

### `SET key value timestamp`

Set a `value` and `timestamp` for the register at `key`.

If the value/timestamp pair currently held in the register has a higher timestamp than the given one, the operation will be ignored. If the register receives another `SET` later with a higher timestamp, this value/timestamp pair will be overwritten.

Returns a simple string reply of `OK`, regardless of whether the update was ignored due to being outdated.

## Examples

```sh
jylis> TREG GET mykey
1) ""
2) (integer) 0
jylis> TREG SET mykey "hello" 10
OK
jylis> TREG GET mykey
1) "hello"
2) (integer) 10
jylis> TREG SET mykey "world" 15
OK
jylis> TREG GET mykey
1) "world"
2) (integer) 15
jylis> TREG SET mykey "outdated" 5
OK
jylis> TREG GET mykey
1) "world"
2) (integer) 15
```

## Detailed Semantics

- Only a single value/timestamp pair is retained in the register at any time.

- When comparing any two value/timestamp pairs `A` and `B`, the `A` pair takes precedence over the `B` pair if and only if:
    - the timestamp for `A` is greater than that of `B`, ***OR***
    - the timestamps are the same, ***AND***
        - the *value* for `A` is greater than that of `B` (by sorting rules).

## Caveats & Pitfalls

- As with all eventually-consistent data types, you can't guarantee that the value read from any two nodes will be the same. Changes take time to propagate through the distributed system, and your application should be written with the expectation of seeing inconsistent values. In general, you should assume that nothing is immediate, nothing is atomic, and nothing is ordered.

- Because conflict resolution of this data type is based solely on the logical timestamp, the semantics will only be as useful as the timestamps are.

    - If you're using clock times for the logical timestamps, you have to account for clock drift and recognize that distributed clocks will never be perfectly in sync. In other words, the needs of your application have to be flexible enough to still behave correctly enough when clock drift between nodes allows "older" writes to overwrite "newer" ones, up to the maximum amount of drift between any two clocks that are writing to the same register.

- Because the lower timestamps are always discarded in favor of higher ones, accidentally updating with an inappropriately high timestamp is an irreversible mistake - you can't "turn back time".

    - The value and the timestamp of the register can never be "cleared" back to a value of zero once the logical timestamp has been raised above zero, as the higher-timestamped value would always mask the zero-timestamped one.

    - If you're accepting end-user clock time as the logical timestamp, you should consider capping the maximum timestamp that the application allows to pass input validation to some point in the near future (allowing for some amount of clock drift). If you allow the end-user to provide a timestamp in the distant future, then they'll be unable to provide any values "in the present" until that distant future date is reached, likely leaving the register in a useless state.

- Because the timestamp is an unsigned 64-bit integer, the maximum timestamp value that can be represented is limited.

    - When designing a solution, care should be taken to choose a timestamp representation that will not increase beyond the maximum 64-bit unsigned value over the life of the application. For example, if your timestamp represents *microseconds* since the unix epoch, that representation will overflow in the year 2028, but if you choose *milliseconds* since the unix epoch, that representation will overflow in the year 584556019.
