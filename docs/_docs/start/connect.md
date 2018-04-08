---
title: Connecting with a Client
permalink: /docs/connect/
---

# Connecting with a Client

Once you've got a working `jylis` binary (or docker container), you'll want to set up a client that can connect to the running server and issue commands.

Jylis uses the [RESP protocol](https://redis.io/topics/protocol) created and popularized by [Redis](https://redis.io) for client/server communication. There are [many clients](https://redis.io/clients) available for Redis, and any of them should be compatible with Jylis, provided that they let you issue arbitrary commands - the data types and commands supported by Jylis are different from those of Redis, but the protocol is the same.

By default, the Jylis server will listen on the same default port as Redis (`6379`), so Redis clients should connect easily, even with default configuration.

One particularly convenient client for demonstration purposes is [`redis-cli`](https://redis.io/topics/rediscli), a small CLI program that ships with Redis. Running both `jylis` and `redis-cli` with the default options should set up an interactive session between the client and server on port `6379`.

## Sending Commands

Once you've established a connection to the Jylis server, you can try to send your first command. We know that [`GCOUNT`](../gcount) is one of the [supported data types](../types), so let's just type that and see what happens.

```sh
127.0.0.1:6379> GCOUNT
(error) BADCOMMAND (could not parse command)
The following are valid operations for this data type
GCOUNT INC key value
GCOUNT GET key
```

We got an error telling us that the command was invalid, but it was useful enough to tell us what kind of commands are expected for this data type. Now we can try typing one of those, using an arbitrary key (`mykey`):

```sh
127.0.0.1:6379> GCOUNT GET mykey
(integer) 0
```

This is a counter we've never increased, and it didn't even exist before this invocation, but we can see that it's treated as having a base value of zero. Now, let's try increasing it, then reading back the increased value:

```sh
127.0.0.1:6379> GCOUNT INC mykey 10
OK
127.0.0.1:6379> GCOUNT GET mykey
(integer) 10
```

And, just to confirm everything's working as expected, we can try increasing and reading it again, expecting to:

```sh
127.0.0.1:6379> GCOUNT INC mykey 15
OK
127.0.0.1:6379> GCOUNT GET mykey
(integer) 25
```

The example worked through here was taken from [the documentation for the `GCOUNT`](../gcount#examples) data type. Every data type documentation page includes such examples, and working through them interactively in this way is a great way to get acquainted with those data types.