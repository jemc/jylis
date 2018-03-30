# `UJSON` - Unordered JSON (Nested Observed-Remove Maps and Sets)

A UJSON node holds arbitrarily nested collections of unordered values, represented with JSON syntax. It is possible to read or modify either all or part of the data set, and concurrent modifications are resolved with causal observed-remove semantics (any value that is locally visible can be removed).

A UJSON map is an unordered data structure represented with JSON object syntax, mapping each key to a value, a set, or a nested map.

```json
{ "fruit": "apple", "properties": { "color": "red", "edible": true }] }]
```

A UJSON set is an unordered data structure represented with JSON array syntax, containing elements where each is a value or a nested map.

```json
[1, 100, { "fruit": ["apple", "banana", "currant"] }]
```

A UJSON value is one of the four JSON primitive types: a string (`"apple"`), a number (`100`), a boolean (`true`/`false`), or `null`.

Though UJSON data is represented with standard JSON syntax, not all JSON data sets can be stored faithfully as UJSON. That is, any valid JSON can be used as input for a UJSON node, but parts of the data may be merged and/or collapsed in adherence to the semantics of UJSON. See [UJSON Primer](#ujson-primer) for more information.

## Functions

### `GET key [key...]`

Get the JSON representation of the data currently held at `key`.

Optionally, additional keys can be specified to read specific data from nested maps, with each key in the list representing a key in the next nested map.

If there is no data located at or under the specified path of keys (or to put it in more traditional JSON terms, if any of the keys are missing along that path), an empty string will be returned.

If there is a single value at that key path, and no values at any paths nested at deeper levels of the same prefix, that single value will be returned (formatted as a JSON primitive value).

If there are multiple values located at that same path, a set will be returned (formatted as a JSON array). Values located at further nested keys will be represented as a map (formatted as a JSON object).

When multiple values are observed at a particular path as a set, note that this may either be an intentional arrangement (the result of using the `INS` command to add more elements to a set), or a result of concurrent `SET` operations that each left a different value at that path. In such situations, it is the responsibility of the application to determine how to deal with the multiple values in the result, either by resolving them to a single value using some application-specific judgment or choosing to leave them as a logical set.

The JSON representation will be returned as a string.

### `SET key [key...] ujson`

Store the given `ujson` data at the given `key`.

Optionally, additional keys can be specified to store data at a specific path inside nested maps, with each key in the list representing a key in the next nested map.

The `ujson` parameter must be a valid JSON-formatted string, containing a map, set, or primitive value. The data will be merged and collapsed according to UJSON semantics when it is stored. See the [UJSON Primer](#ujson-primer) for more information.

The `SET` command may be used freely with key paths that do not yet exist, and nested maps will be created along those paths to contain the new values. There is no need to initialize the layers of the nested maps one at a time - all necessary layers will be established implicitly just by mentioning the keys.

If there is no data located at or under the specified path of keys (or to put it in more traditional JSON terms, if any of the keys are missing along that path), an empty string will be returned.

Any values currently located at or under the specified key path will be cleared away, as if the `CLR` command had been used for that path beforing writing the new data to it. That is, the data written to the path will not be merged with the existing data at and under that path.

However, concurrent `SET` operations on different replicas may result in data of the two operations being merged together when the results are converged. Concurrent modifications are those that have no causal relationship - neither change was locally visible yet on the replica where the other change was made.
When converging such changes results in multiple values at the same key path, those values will be rendered as an unordered set. Similarly, merged map keys that are located under the same key path will be rendered as the same unordered map.

In cases where removal of a value at a particular key path happens concurrently with an insertion operation of an identical value at the same path, the insertion will take precedence over the removal ("add wins" semantics).

### `CLR key [key...]`

Remove all data stored at or under the given `key`.

Optionally, additional keys can be specified to clear data from a specific path inside nested maps, with each key in the list representing a key in the next nested map.

If there is no data located at or under the specified path of keys, the command will silently succeed, having had no actual effect.

When values are removed, if the key paths under which they were located become empty, those key paths will be pruned. To put it another way, UJSON has no concept of empty maps or empty sets, other than to say that the map or set no longer exists because there are no values to track within it. See the [UJSON Primer](#ujson-primer) for more information.

Only values that are locally visible on the current replica can be removed in this operation. That is, new values that were introduced concurrently and converged later will not be affected by the `CLR` operation, because it can only clear data that has a "happened-before" causal relationship.

In cases where removal of a value at a particular key path happens concurrently with an insertion operation of an identical value at the same path, the insertion will take precedence over the removal ("add wins" semantics).

### `INS key [key...] value`

Insert the given `value` as a new element in the set of values stored at `key`.

Optionally, additional keys can be specified to store the value at a specific path inside nested maps, with each key in the list representing a key in the next nested map.

The `value` parameter must be a valid JSON-formatted primitive value, (a number, string, boolean, or `null`). Maps and sets are not allowed in this command (though they are allowed in the `SET` command).

The `INS` command may be used freely with key paths that do not yet exist, and nested maps will be created along those paths to contain the new values. There is no need to initialize the layers of the nested maps one at a time - all necessary layers will be established implicitly just by mentioning the keys.

Any values currently located at or under the specified key path will be retained, contrary to the behaviour of the `SET` command. That is, the value will be added alongside any existing values at that path, forming a logical set.

In cases where removal of a value at a particular key path happens concurrently with an insertion operation of an identical value at the same path, the insertion will take precedence over the removal ("add wins" semantics).

### `RM key [key...] value`

Remove the specified `value` from the set of values stored at `key`.

Optionally, additional keys can be specified to remove from a specific path inside nested maps, with each key in the list representing a key in the next nested map.

If the specified value is not currently stored at the specified path, the command will have no effect. It will never have an effect on non-identical values stored at that key path, or at other key paths.

When a value is removed, if the key path under which it was located becomes empty, that key path will be pruned. To put it another way, UJSON has no concept of empty maps or empty sets, other than to say that the map or set no longer exists because there are no values to track within it. See the [UJSON Primer](#ujson-primer) for more information.

Only a value that is locally visible on the current replica can be removed in this operation. That is, new values that were introduced concurrently and converged later will not be affected by the `RM` operation, because it can only remove a value was stored with a "happened-before" causal relationship.

In cases where removal of a value at a particular key path happens concurrently with an insertion operation of an identical value at the same path, the insertion will take precedence over the removal ("add wins" semantics).

## Examples

```json
{
  "username": "demo-user",
  "created_at": 1514793601,
  "banned": false,
  "contact_info": {
    "email": "demo-user@example.com",
  }
}
```

```sh
jylis> TREG GET mykey
(nil)
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


## UJSON Primer

UJSON is very similar to JSON, but it has some important deviations that should be kept in mind when modeling application data:

#### Nothing is ordered.

- Instead of `[`/`]` brackets representing ordered arrays as they do in JSON, these brackets represent an unordered set in UJSON.
- The `{`/`}` brackets already represent an unordered data structure in JSON, and remain so in UJSON.

#### The world is flat.

- A UJSON node tracks only terminal values ("leaves" of the tree).
- Rather than modeling the data as a nested maps and sets, UJSON sees a flat set of primitive values (strings, numbers, booleans, `null`s) and the key path of each.

#### To be empty is to perish.

- Because collections are only rendered as part of rendering the path for a terminal value, empty collections are not rendered at all.
- A set with one element is no longer a set - it is rendered as the single element with no brackets around it.
- A set with zero elements disappears entirely, and so does the key that was pointing to it.
- A map with zero keys disappears as well, potentially causing cascading disappearances up the nested data structure - entire trees of nested maps that no longer have any terminal values can be eliminated without losing data, because terminal values are the only real data.

#### Store any value, anywhere.

- If nested maps implicitly disappear when they no longer hold terminal values, they can also implicitly appear as soon as there is a terminal value to store in them.
- Any value can be added at any key path, ad hoc, without bothering to first create the nested maps containing it.

#### A rose is a rose.

- Because terminal values and their associated key paths roughly constitute a flat set in total, there is no distinguishing between the same values appearing at the same path.
- Adding a duplicate value to an existing set will have no effect - it just idempotently confirms the value's membership in the set.

#### All roads lead to Rome.

- Because terminal values exist on a flat plane of key paths, there are no distinctions between different arrivals at the same path.
- A rendered set can contain at most one map within it - if you supply a set with more than one map within it, the maps will be merged together because there is no part of a key path that represents a particular or distinct position in a set.
- As such, while it is possible to have multiple primitive values alongside a map in a set, there can be only one map in that set in the merged output.
- Similarly, sets cannot be nested directly within sets because there are no keys involved to form a distinct key path - any such nested sets will be flattened into a single set, just under the nearest key (or at the root of the node).

## Detailed Semantics

- Every modification operation is associated with a point in causal history, consisting of the unique replica id where the operation was introduced and a sequence number local to that replica.

- Total causal history is tracked for each replica, and all replicas are able to recognize and ignore a duplicate modification operation that has already been observed. Note that this is implemented in an optimized way with compaction of immutable history such that the memory devoted to causal history tracking will not grow without bound.

- A UJSON node is composed of a set of terminal values, with associated paths.

- The set of path/value pairs exist within causal history, and can be added and removed with "add wins", "observed remove" semantics.

- The path/value pairs in the set are merged together using a commutative merge function to render as the unordered data structures comprising UJSON.

## Caveats & Pitfalls

- As with all eventually-consistent data types, you can't guarantee that the value read from any two nodes will be the same. Changes take time to propagate through the distributed system, and your application should be written with the expectation of seeing inconsistent values. In general, you should assume that nothing is immediate, nothing is atomic, and nothing is ordered.

- TODO: Expand with more caveats and pitfalls for this data type.
