# `>jylis` [![CircleCI](https://circleci.com/gh/jemc/jylis.svg?style=shield)](https://circleci.com/gh/jemc/jylis) [![Docker](https://img.shields.io/microbadger/image-size/jemc/jylis/latest.svg)](https://hub.docker.com/r/jemc/jylis/)

A distributed in-memory database for Conflict-free Replicated Data Types (CRDTs).

### Status

This project is still a work in progress. Expect rapid, breaking changes.

### Try

- Run a single server: `docker run -ti --rm -p 6379:6379 jemc/jylis`
- Execute commands: `redis-cli -p 6379`

### Read

Much of the documentation is still not written, but you can read about the available data types [here](https://github.com/jemc/jylis/tree/master/docs/types).
