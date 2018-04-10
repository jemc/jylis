---
title: TLOG - Timestamped Log
permalink: /docs/types/tlog/
---

# `TLOG` - Timestamped Log<br>(Retain Latest Entries)

A timestamped log holds a list of entries, each with a value and logical timestamp, sorted by timestamp with the most recent entries appearing first.

To limit the depth, each log has a cutoff timestamp - the minimum timestamp value for entries that will be retained. Any observed log entries with an earlier timestamp than the cutoff will be discarded. The cutoff timestamp can be increased (moved forward in time), but never decreased. If unlimited retention is desired, the cutoff timestamp can be left at the base value of zero.

The logical timestamp is a 64-bit unsigned integer. It may be used to represent anything appropriate to the application; perhaps milliseconds since the unix epoch, or perhaps a sequence number.

## Functions

### `GET key [count]`

Get the list of `value`/`timestamp` entries for the log at `key`.

All observed log entries whose timestamp is greater than or equal to the cutoff timestamp will be shown, sorted in descending order by timestamp.

To limit the number of entries returned, an optional `count` may be specified. For example, specifying a `count` of `1` will return only the latest entry (the one with the highest timestamp). The number of entries returned will be either the given `count` or the total size of the log, whichever is smaller.

Returns an array where each element is a two-element array containing the value and timestamp of that entry.

The values will be returned as string, and the timestamps as integers.

### `INS key value timestamp`

Insert a `value`/`timestamp` entry into the log at `key`.

The log is sorted by timestamp, so the new entry will be inserted at the correct position in that sort order. If two different entries have the same timestamp, they will be secondarily sort by string value. If the new entry has an identical timestamp *and* value to an existing entry, it will be treated as a duplicate and ignored.

If the timestamp of the new entry is earlier than the current cutoff timestamp for the log, the new entry will be treated as outdated and ignored.

Returns a simple string reply of `OK`, regardless of whether the entry was ignored due to being a duplicate or outdated.

### `SIZE key`

Return the number of entries in the log at `key`, as an integer.

### `CUTOFF key`

Return the current cutoff timestamp of the log at `key`, as an integer.

### `TRIMAT key timestamp`

Raise the cutoff timestamp of the log, causing any entries to be discarded whose timestamp is earlier than the newly given `timestamp`.

The cutoff timestamp can only be moved forward in time, so if the newly given timestamp is earlier than the current cutoff timestamp, the cutoff timestamp will not be changed.

Returns a simple string reply of `OK`.

### `TRIM key count`

Raise the cutoff timestamp of the log to retain at least `count` entries, by setting the cutoff timestamp to the timestamp of the entry at index `count - 1`in the log. Any entries with an earlier timestamp than the entry at that index will be discarded. If `count` is zero, this is the same as calling the `CLR` command.

This is a useful command for keeping the size of the log near a particular count. It's always possible for the log to end up with a few more entries than the trimmed count, but it's still a useful way to manage retention and keep the size of the data structure from growing without bound.

Returns a simple string reply of `OK`.

### `CLR key`

Raise the cutoff timestamp to be the timestamp of the latest entry plus one, such that all local entries in the log will be discarded due to having timestamps earlier than the cutoff timestamp. If there are no entries in the local log, this method will have no effect.

Returns a simple string reply of `OK`.

## Examples

```sh
jylis> TLOG INS chat "jemc: hello, world!" 1523258089149
OK
jylis> TLOG INS chat "world: hey jemc, how you been?" 1523258145906
OK
jylis> TLOG INS chat "world: must be nice..." 1523258158785
OK
jylis> TLOG INS chat "jemc: feeling pretty good these days" 1523258152362
OK
jylis> TLOG SIZE chat
(integer) 4
jylis> TLOG GET chat
1) 1) "world: must be nice..."
   2) (integer) 1523258158785
2) 1) "jemc: feeling pretty good these days"
   2) (integer) 1523258152362
3) 1) "world: hey jemc, how you been?"
   2) (integer) 1523258145906
4) 1) "jemc: hello, world!"
   2) (integer) 1523258089149
jylis> TLOG GET chat 1
1) 1) "world: must be nice..."
   2) (integer) 1523258158785
jylis> TLOG TRIM chat 3
OK
jylis> TLOG SIZE chat
(integer) 3
jylis> TLOG CUTOFF chat
(integer) 1523258145906
jylis> TLOG TRIMAT chat 1523258152362
OK
jylis> TLOG SIZE chat
(integer) 2
jylis> TLOG CUTOFF chat
(integer) 1523258152362
jylis> TLOG GET chat
1) 1) "world: must be nice..."
   2) (integer) 1523258158785
2) 1) "jemc: feeling pretty good these days"
   2) (integer) 1523258152362
jylis> TLOG CLR chat
OK
jylis> TLOG GET chat
(empty list)
```

## Detailed Semantics

- Entries, each consisting of a value/timestamp pair, are maintained in a sorted list.

- Two lists `A` and `B` are merged by combining all entried into a single list, removing duplicates, and sorting the total list.

- When comparing any two entries `A` and `B`, the two are determined to be duplicates of each other if and only if both the timestamp and the value are equal.

- When comparing any two entries `A` and `B`, the `A` entry appears earlier in the list (later in time) than the `B` entry if and only if:
    - the timestamp for `A` is greater than that of `B`, ***OR***
    - the timestamps are the same, ***AND***
        - the *value* for `A` is greater than that of `B` (by sorting rules).

- A cutoff timestamp is also maintained for each list, implemented as a grow-only value.

- Two cutoff timestamps `A` and `B` are merged by selecting the higher value of the two, if they are unequal.

- When applying a cutoff timestamp change, an entry will be removed from the list if and only if its timestamp is strictly less than that cutoff timestamp.

## Caveats & Pitfalls

- As with all eventually-consistent data types, you can't guarantee that the value read from any two nodes will be the same. Changes take time to propagate through the distributed system, and your application should be written with the expectation of seeing inconsistent values. In general, you should assume that nothing is immediate, nothing is atomic, and changes are not ordered.

- Because conflict resolution of this data type is based solely on the logical timestamp, the semantics will only be as useful as the timestamps are.

    - If you're using clock times for the logical timestamps, you have to account for clock drift and recognize that distributed clocks will never be perfectly in sync. Minimizing clock drift is less important for the `TLOG` than it is for [`TREG`](../treg), because `TLOG` is capable of maintaining many values near the same timestamp. However, you'll still need to be aware of clock drift when removing values by raising the cutoff timestamp, recognizing that the relative time at that point in history on other servers may have differed.

- Because the cutoff timestamp is a grow-only value, accidentally updating it with an inappropriately high timestamp is an irreversible mistake - you can't you can't lower the cutoff timestamp (move it backward in time), and you can't restore entries that have been "cut off" from the log, including new entries being written with a timestamp older than the cutoff.

    - You should consider capping the maximum cutoff timestamp that the application is allowed to apply to the log to some point in the near future (allowing for some amount of clock drift). If you allow the cutoff timestamp to be raised to a timestamp in the distant future, you'll be unable to write any entries "in the present" until that distant future date is reached, leaving the log in an empty and useless state.

- Because the timestamp is an unsigned 64-bit integer, the maximum timestamp value that can be represented is limited.

    - When designing a solution, care should be taken to choose a timestamp representation that will not increase beyond the maximum 64-bit unsigned value over the life of the application. For example, if your timestamp represents *microseconds* since the unix epoch, that representation will overflow in the year 2028, but if you choose *milliseconds* since the unix epoch, that representation will overflow in the year 584556019.
